import SwiftUI

struct HUDView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Qota")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                if let lastRefresh = store.lastRefresh {
                    TimelineView(.periodic(from: .now, by: 30)) { _ in
                        Text(relativeRefresh(lastRefresh))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            ForEach(ProviderID.allCases) { id in
                ProviderRow(
                    id: id,
                    status: store.status(for: id),
                    warnAt: store.warnPercent,
                    criticalAt: store.criticalPercent
                )
            }
        }
        .padding(14)
        .frame(width: 328)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }

    private func relativeRefresh(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        return "\(max(1, seconds / 60))m ago"
    }
}

struct ProviderRow: View {
    var id: ProviderID
    var status: ProviderStatus
    var warnAt: Double
    var criticalAt: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(id.tint)
                    .frame(width: 7, height: 7)
                Text(id.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                if let plan = status.snapshot?.planLabel, !plan.isEmpty {
                    Text(plan)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.primary.opacity(0.06), in: Capsule())
                }
                Spacer()
                trailingLabel
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let snapshot = status.snapshot {
                VStack(spacing: 5) {
                    ForEach(snapshot.windows) { window in
                        windowRow(window)
                    }
                }
                if case .stale = status {
                    Text(status.detailMessage ?? "Stale")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.orange)
                }
            } else {
                Text(status.detailMessage ?? "Unavailable")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var trailingLabel: some View {
        switch status {
        case .loading:
            ProgressView()
                .controlSize(.mini)
        case .ready(let snapshot), .stale(let snapshot, _, _):
            Text(snapshot.headline)
                .foregroundStyle(.primary)
        default:
            Text("—")
        }
    }

    private func windowRow(_ window: UsageWindow) -> some View {
        HStack(spacing: 8) {
            Text(window.label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            UsageBar(
                percent: window.usedPercent,
                tint: id.tint,
                warnAt: warnAt,
                criticalAt: criticalAt
            )
            Text(PercentFormat.used(window.usedPercent))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
            Text(window.resetsAt.map { "· \(ResetFormat.compact($0))" } ?? "")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.tertiary)
                .frame(width: 58, alignment: .leading)
        }
    }
}
