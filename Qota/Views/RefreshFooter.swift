import SwiftUI

/// "Updated 2 min ago" plus a manual refresh control, shared by the popover and the HUD.
struct RefreshFooter: View {
    @EnvironmentObject private var store: UsageStore
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            // `Text(_:style:.relative)` re-renders itself, so the age stays honest without a timer.
            Group {
                if store.isRefreshing {
                    Text("Refreshing…")
                } else if let updated = store.lastUpdated {
                    Text("Updated ") + Text(updated, style: .relative) + Text(" ago")
                } else {
                    Text("No data yet")
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                store.refreshAll()
            } label: {
                if compact {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)
            .help("Refresh now")
        }
    }
}
