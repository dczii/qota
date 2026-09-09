import SwiftUI

struct HUDView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(ProviderID.allCases) { provider in
                ProviderRow(
                    provider: provider,
                    snapshot: store.snapshot(for: provider),
                    staleReason: store.staleReason(for: provider),
                    compact: true
                )
            }

            Divider()
            RefreshFooter(compact: true)
        }
        .padding(12)
        .frame(width: 250)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        )
    }
}
