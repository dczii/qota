import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Qota")
                    .font(.system(size: 13, weight: .semibold))
                Text(AppInfo.version)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            RefreshFooter()

            ForEach(ProviderID.allCases) { provider in
                ProviderRow(
                    provider: provider,
                    snapshot: store.snapshot(for: provider),
                    staleReason: store.staleReason(for: provider)
                )
            }

            Divider()

            Toggle("Show floating HUD", isOn: $store.hudVisible)
                .toggleStyle(.switch)
                .controlSize(.small)

            Toggle("Open at login", isOn: Binding(
                get: { store.openAtLogin },
                set: { store.openAtLogin = $0 }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            HStack {
                Spacer()
                Button("Quit Qota") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
