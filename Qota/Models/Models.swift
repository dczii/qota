import Foundation
import SwiftUI

enum ProviderID: String, CaseIterable, Identifiable, Sendable {
    case claude
    case codex
    case cursor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        }
    }

    var shortCode: String {
        switch self {
        case .claude: return "Cl"
        case .codex: return "Cx"
        case .cursor: return "Cu"
        }
    }

    var tint: Color {
        switch self {
        case .claude: return Color(red: 0.90, green: 0.45, blue: 0.22)
        case .codex: return Color(red: 0.18, green: 0.78, blue: 0.58)
        case .cursor: return Color(red: 0.29, green: 0.58, blue: 0.98)
        }
    }
}

struct UsageWindow: Equatable, Identifiable, Sendable {
    var id: String
    var label: String
    var usedPercent: Double
    var remainingText: String?
    var resetsAt: Date?

    var remainingPercent: Double { max(0, min(100, 100 - usedPercent)) }
}

struct ProviderSnapshot: Equatable, Sendable {
    var provider: ProviderID
    var planLabel: String?
    var fetchedAt: Date
    var windows: [UsageWindow]
    var footnote: String?

    var primary: UsageWindow? { windows.first }

    var headline: String {
        if let remaining = primary?.remainingText, !remaining.isEmpty {
            return remaining
        }
        if let percent = primary?.usedPercent {
            return "\(Int(percent.rounded()))%"
        }
        return "—"
    }

    var maxUsedPercent: Double {
        windows.map(\.usedPercent).max() ?? 0
    }
}

enum ProviderStatus: Equatable, Sendable {
    case loading
    case signedOut(String)
    case unavailable(String)
    case rateLimited(retryAfter: Date?)
    case ready(ProviderSnapshot)
    case stale(ProviderSnapshot, Date, String)
    case failed(String)

    var snapshot: ProviderSnapshot? {
        switch self {
        case .ready(let snapshot), .stale(let snapshot, _, _):
            return snapshot
        default:
            return nil
        }
    }

    var isBusy: Bool {
        if case .loading = self { return true }
        return false
    }

    var detailMessage: String? {
        switch self {
        case .loading:
            return "Checking…"
        case .signedOut(let message), .unavailable(let message), .failed(let message):
            return message
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Rate limited · retry \(ResetFormat.compact(retryAfter))"
            }
            return "Rate limited · backing off"
        case .stale(_, _, let reason):
            return reason
        case .ready:
            return nil
        }
    }
}

enum UsageError: LocalizedError {
    case signedOut(String)
    case unavailable(String)
    case rateLimited(TimeInterval?)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .signedOut(let message), .unavailable(let message), .failed(let message):
            return message
        case .rateLimited:
            return "Rate limited"
        }
    }
}
