import SwiftUI

struct MenuBarLabel: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "gauge.with.dots.needle.67percent")
            Text(store.compactMenuTitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(labelColor)
        .help(store.compactMenuTitle)
    }

    private var labelColor: Color {
        if store.highestUsage >= store.criticalPercent { return .red }
        if store.highestUsage >= store.warnPercent { return .orange }
        return .primary
    }
}
