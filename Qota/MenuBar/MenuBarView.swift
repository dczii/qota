import AppKit
import ServiceManagement
import SwiftUI

struct MenuBarView: View {
    @Environment(UsageStore.self) private var store
    @State private var loginError: String?
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 8)
            ForEach(ProviderID.allCases) { id in
                ProviderRow(
                    id: id,
                    status: store.status(for: id),
                    warnAt: store.warnPercent,
                    criticalAt: store.criticalPercent
                )
                .padding(.vertical, 8)
                if id != .cursor {
                    Divider()
                }
            }
            Divider().padding(.vertical, 8)
            controls
        }
        .padding(14)
        .frame(width: 360)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Qota")
                    .font(.headline)
                Text(store.isRefreshing ? "Refreshing…" : "Plan quota for Claude, Codex, and Cursor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.refreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)
            .help("Refresh now")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show floating HUD", isOn: hudVisibleBinding)
            Toggle("Open at login", isOn: $openAtLogin)
                .onChange(of: openAtLogin) { _, enabled in
                    setLoginItem(enabled)
                }
            if let loginError {
                Text(loginError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack {
                Button("Quit Qota") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .toggleStyle(.checkbox)
        .font(.system(size: 12))
    }

    private var hudVisibleBinding: Binding<Bool> {
        Binding(
            get: { store.hudVisible },
            set: { store.hudVisible = $0 }
        )
    }

    private func setLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = "Could not change login item. Move Qota to Applications and try again."
            openAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
