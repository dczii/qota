import AppKit
import SwiftUI

@main
struct QotaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var store = UsageStore.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverView().environmentObject(store)
        } label: {
            Text(store.menuBarSummary)
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = UsageStore.shared
    private let hud = HUDController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        store.onHUDVisibilityChange = { [weak self] visible in
            guard let self else { return }
            if visible {
                hud.show(store: store)
            } else {
                hud.hide()
            }
        }
        if store.hudVisible {
            hud.show(store: store)
        }
        store.start()
    }
}
