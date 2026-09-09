import SwiftUI

extension ProviderID {
    var tint: Color {
        switch self {
        case .claude: return Color(red: 0.85, green: 0.47, blue: 0.30)
        case .codex: return Color(red: 0.30, green: 0.72, blue: 0.55)
        case .cursor: return Color(red: 0.38, green: 0.55, blue: 0.92)
        }
    }
}

struct ProviderRow: View {
    var provider: ProviderID
    var snapshot: ProviderSnapshot?
    var staleReason: String?
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(provider.displayName)
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                if let plan = snapshot?.planLabel, !compact {
                    Text(plan.capitalized)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let headline = snapshot?.headline {
                    Text(headline)
                        .font(.system(size: compact ? 10 : 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if let snapshot, !snapshot.windows.isEmpty {
                ForEach(snapshot.windows) { window in
                    windowRow(window)
                }
                if let footnote = snapshot.footnote, !compact {
                    Text(footnote)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if let staleReason {
                Text(snapshot == nil ? staleReason : "\(staleReason) — showing last known")
                    .font(.system(size: 10))
                    .foregroundStyle(snapshot == nil ? .secondary : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(snapshot == nil && staleReason != nil ? 0.75 : 1)
    }

    @ViewBuilder
    private func windowRow(_ window: UsageWindow) -> some View {
        HStack(spacing: 8) {
            Text(window.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: compact ? 34 : 46, alignment: .leading)

            UsageBar(percent: window.usedPercent, tint: provider.tint, warnAt: 75, criticalAt: 90)

            Text(PercentFormat.used(window.usedPercent))
                .font(.system(size: 10, design: .rounded))
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)

            if let resets = window.resetsAt {
                Text(ResetFormat.compact(resets))
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            } else if let remaining = window.remainingText {
                Text(remaining)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
        }
    }
}
