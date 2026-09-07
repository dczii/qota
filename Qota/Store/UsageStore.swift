import Foundation
import Observation

@MainActor
@Observable
final class UsageStore {
    var claude: ProviderStatus = .loading
    var codex: ProviderStatus = .loading
    var cursor: ProviderStatus = .loading
    var lastRefresh: Date?
    var isRefreshing = false
    var hudVisible: Bool = Preferences.hudVisible {
        didSet { Preferences.hudVisible = hudVisible }
    }

    var warnPercent: Double { Preferences.warnPercent }
    var criticalPercent: Double { Preferences.criticalPercent }

    private var loop: Task<Void, Never>?
    private var lastClaudeAttempt: Date?
    private let claudeProvider = ClaudeProvider()
    private let codexProvider = CodexProvider()
    private let cursorProvider = CursorProvider()

    func status(for id: ProviderID) -> ProviderStatus {
        switch id {
        case .claude: claude
        case .codex: codex
        case .cursor: cursor
        }
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func refreshNow() {
        Task { await refresh(forceClaude: true) }
    }

    var compactMenuTitle: String {
        ProviderID.allCases.map { id in
            compactToken(for: status(for: id), id: id)
        }.joined(separator: "  ")
    }

    var highestUsage: Double {
        ProviderID.allCases.compactMap { status(for: $0).snapshot?.maxUsedPercent }.max() ?? 0
    }

    private func compactToken(for status: ProviderStatus, id: ProviderID) -> String {
        switch status {
        case .loading:
            return "\(id.shortCode)…"
        case .ready(let snapshot), .stale(let snapshot, _, _):
            return "\(id.shortCode) \(snapshot.headline)"
        default:
            return "\(id.shortCode)—"
        }
    }

    private func runLoop() async {
        await refresh(forceClaude: true)
        while !Task.isCancelled {
            let interval: TimeInterval = hudVisible ? 60 : 150
            try? await Task.sleep(for: .seconds(interval))
            await refresh(forceClaude: false)
        }
    }

    private func refresh(forceClaude: Bool) async {
        isRefreshing = true
        lastRefresh = Date()
        async let claudeUpdate: Void = refreshClaude(force: forceClaude)
        async let codexUpdate: Void = assign(.codex, await codexProvider.fetch())
        async let cursorUpdate: Void = assign(.cursor, await cursorProvider.fetch())
        _ = await (claudeUpdate, codexUpdate, cursorUpdate)
        isRefreshing = false
    }

    private func refreshClaude(force: Bool) async {
        if !force, let lastClaudeAttempt, Date().timeIntervalSince(lastClaudeAttempt) < 170 {
            return
        }
        lastClaudeAttempt = Date()
        await assign(.claude, await claudeProvider.fetch())
    }

    private func assign(_ id: ProviderID, _ next: ProviderStatus) {
        let merged = merge(previous: status(for: id), next: next)
        switch id {
        case .claude: claude = merged
        case .codex: codex = merged
        case .cursor: cursor = merged
        }
    }

    private func merge(previous: ProviderStatus, next: ProviderStatus) -> ProviderStatus {
        switch next {
        case .ready:
            return next
        case .failed, .unavailable, .rateLimited:
            if let snapshot = previous.snapshot {
                return .stale(snapshot, snapshot.fetchedAt, next.detailMessage ?? "Stale")
            }
            return next
        default:
            return next
        }
    }
}
