import AppKit
import SwiftUI

@main
struct QotaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appDelegate.store)
        } label: {
            MenuBarLabel()
                .environment(appDelegate.store)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = UsageStore()
    private var hud: HUDPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        hud = HUDPanelController(store: store)
        hud?.setVisible(store.hudVisible)
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        CodexRPCClient.shared.shutdown()
    }
}
