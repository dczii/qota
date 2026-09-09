import Foundation

enum ProviderID: String, CaseIterable, Identifiable, Sendable {
    case claude
    case codex
    case cursor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex CLI"
        case .cursor: return "Cursor"
        }
    }

    /// Short tag used in the menu-bar title, where width is scarce.
    var menuBarTag: String {
        switch self {
        case .claude: return "Cl"
        case .codex: return "Cx"
        case .cursor: return "Cu"
        }
    }
}

struct UsageWindow: Identifiable, Sendable, Equatable {
    var id: String
    var label: String
    var usedPercent: Double
    var remainingText: String?
    var resetsAt: Date?
}

struct ProviderSnapshot: Sendable, Equatable {
    var provider: ProviderID
    var planLabel: String?
    var fetchedAt: Date
    var windows: [UsageWindow]
    var footnote: String?
    /// Short value shown instead of a percentage when a provider reports spend rather than a window.
    var headline: String?

    /// The window closest to its cap, which is the one worth surfacing in the menu bar.
    var leadWindow: UsageWindow? {
        windows.max { $0.usedPercent < $1.usedPercent }
    }
}

enum ProviderStatus: Sendable, Equatable {
    case loading
    case ready(ProviderSnapshot)
    case signedOut(String)
    case unavailable(String)
    case rateLimited(retryAfter: Date?)
    case failed(String)
    /// The account is valid but has no plan quota to report (for example an Anthropic API organization).
    case notApplicable(String)

    var snapshot: ProviderSnapshot? {
        if case .ready(let snapshot) = self { return snapshot }
        return nil
    }

    /// Reason text for every non-success state, used to annotate stale rows.
    var reason: String? {
        switch self {
        case .loading, .ready:
            return nil
        case .signedOut(let message), .unavailable(let message), .failed(let message), .notApplicable(let message):
            return message
        case .rateLimited(let retryAfter):
            guard let retryAfter else { return "Rate limited" }
            return "Rate limited — retry in \(ResetFormat.compact(retryAfter))"
        }
    }
}

enum UsageError: Error, Sendable {
    case signedOut(String)
    case unavailable(String)
    case rateLimited(TimeInterval?)
    case failed(String)
    case notApplicable(String)

    var status: ProviderStatus {
        switch self {
        case .signedOut(let message): return .signedOut(message)
        case .unavailable(let message): return .unavailable(message)
        case .failed(let message): return .failed(message)
        case .notApplicable(let message): return .notApplicable(message)
        case .rateLimited(let seconds): return .rateLimited(retryAfter: seconds.map { Date().addingTimeInterval($0) })
        }
    }
}
