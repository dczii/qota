import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    /// The menu-bar label and the app delegate must observe the same instance, and only
    /// the `App` struct can drive SwiftUI updates, so the store is shared rather than owned.
    static let shared = UsageStore()

    /// Anthropic rate-limits chatty clients on the usage endpoint, so Claude gets a slow lane.
    private static let interval: [ProviderID: TimeInterval] = [
        .claude: 180,
        .codex: 60,
        .cursor: 60
    ]

    @Published private(set) var statuses: [ProviderID: ProviderStatus] = [:]
    /// Last successful read per provider, kept so a transient failure shows stale numbers
    /// with a reason rather than collapsing the row to an error.
    @Published private(set) var lastGood: [ProviderID: ProviderSnapshot] = [:]
    @Published private(set) var inFlight: Set<ProviderID> = []

    @Published var hudVisible: Bool {
        didSet {
            UserDefaults.standard.set(hudVisible, forKey: "hudVisible")
            onHUDVisibilityChange?(hudVisible)
        }
    }

    var onHUDVisibilityChange: ((Bool) -> Void)?

    private let providers: [ProviderID: any UsageProvider] = [
        .claude: ClaudeProvider(),
        .codex: CodexProvider(),
        .cursor: CursorProvider()
    ]
    private var pollers: [Task<Void, Never>] = []

    init() {
        hudVisible = UserDefaults.standard.bool(forKey: "hudVisible")
        for id in ProviderID.allCases {
            statuses[id] = .loading
        }
    }

    func start() {
        guard pollers.isEmpty else { return }
        pollers = ProviderID.allCases.map { id in
            Task { [weak self] in
                while !Task.isCancelled {
                    await self?.refresh(id)
                    let seconds = Self.interval[id] ?? 60
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                }
            }
        }
    }

    func refreshAll() {
        for id in ProviderID.allCases {
            Task { await refresh(id) }
        }
    }

    private func refresh(_ id: ProviderID) async {
        guard let provider = providers[id] else { return }
        inFlight.insert(id)
        defer { inFlight.remove(id) }

        let status = await provider.fetch()
        statuses[id] = status
        if let snapshot = status.snapshot {
            lastGood[id] = snapshot
        }
    }

    var isRefreshing: Bool { !inFlight.isEmpty }

    /// When numbers were last read successfully. Failed polls deliberately do not move this,
    /// so the timestamp always answers "how old is what I am looking at".
    var lastUpdated: Date? {
        lastGood.values.map(\.fetchedAt).max()
    }

    /// Numbers to draw for a row: live if we have them, otherwise the last good read.
    func snapshot(for id: ProviderID) -> ProviderSnapshot? {
        statuses[id]?.snapshot ?? lastGood[id]
    }

    /// Set when the row is showing numbers older than the current status.
    func staleReason(for id: ProviderID) -> String? {
        guard let status = statuses[id], status.snapshot == nil else { return nil }
        if case .loading = status { return lastGood[id] == nil ? nil : "Refreshing" }
        return status.reason
    }

    var menuBarSummary: String {
        let parts = ProviderID.allCases.compactMap { id -> String? in
            guard let snapshot = snapshot(for: id) else { return nil }
            if let window = snapshot.leadWindow {
                return "\(id.menuBarTag) \(PercentFormat.used(window.usedPercent))"
            }
            if let headline = snapshot.headline {
                return "\(id.menuBarTag) \(headline)"
            }
            return nil
        }
        return parts.isEmpty ? "Qota" : parts.joined(separator: "  ")
    }

    /// Highest utilisation across every provider, which drives the menu-bar colour.
    var peakPercent: Double {
        ProviderID.allCases
            .compactMap { snapshot(for: $0)?.leadWindow?.usedPercent }
            .max() ?? 0
    }

    // MARK: - Open at login

    var openAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Only possible from a bundled, signed app; ignore when running the bare binary.
            }
            objectWillChange.send()
        }
    }
}
