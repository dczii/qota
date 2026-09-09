import AppKit
import SwiftUI

/// Owns the always-on-top panel. A plain `Window` scene cannot float above other apps
/// or follow the user across Spaces, so the HUD is an `NSPanel` driven by hand.
@MainActor
final class HUDController {
    private var panel: NSPanel?
    private let frameKey = "hudFrameOrigin"

    func show(store: UsageStore) {
        if let panel {
            panel.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 180),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        // Row content grows and shrinks (a wrapped error message, an extra window), so let the
        // hosting controller drive the panel size instead of freezing it at creation.
        let host = NSHostingController(rootView: HUDView().environmentObject(store))
        host.sizingOptions = [.preferredContentSize]
        panel.contentViewController = host
        // `sizingOptions` only applies on the next layout pass, so seed the size now;
        // positioning against a zero-width frame would park the panel off the screen edge.
        panel.setContentSize(host.view.fittingSize)

        position(panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        if let panel {
            saveOrigin(panel)
            panel.orderOut(nil)
        }
        panel = nil
    }

    private func position(_ panel: NSPanel) {
        if let saved = UserDefaults.standard.string(forKey: frameKey) {
            let point = NSPointFromString(saved)
            if NSScreen.screens.contains(where: { $0.frame.contains(point) }) {
                panel.setFrameOrigin(clamp(point, for: panel))
                return
            }
        }
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(x: visible.maxX - panel.frame.width - 24, y: visible.maxY - panel.frame.height - 24)
        )
    }

    /// A panel that grew since it was last placed must not end up hanging off the screen.
    private func clamp(_ origin: NSPoint, for panel: NSPanel) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(origin) }) ?? NSScreen.main else {
            return origin
        }
        let visible = screen.visibleFrame
        return NSPoint(
            x: min(max(origin.x, visible.minX), visible.maxX - panel.frame.width),
            y: min(max(origin.y, visible.minY), visible.maxY - panel.frame.height)
        )
    }

    private func saveOrigin(_ panel: NSPanel) {
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: frameKey)
    }
}
