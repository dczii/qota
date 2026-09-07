import AppKit
import Observation
import SwiftUI

@MainActor
final class HUDPanelController: NSObject {
    private let store: UsageStore
    private let panel: HUDPanel
    private var hosting: NSHostingView<AnyView>
    private var didRestore = false

    init(store: UsageStore) {
        self.store = store
        let panel = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 328, height: 196),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.animationBehavior = .utilityWindow

        let root = HUDView().environment(store)
        let hosting = NSHostingView(rootView: AnyView(root))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: 328, height: 196))
        panel.contentView = hosting

        self.panel = panel
        self.hosting = hosting
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowMoved),
            name: NSWindow.didMoveNotification,
            object: panel
        )
        startObserving()
    }

    func setVisible(_ visible: Bool) {
        if visible {
            if !didRestore {
                restorePosition()
                didRestore = true
            }
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func startObserving() {
        withObservationTracking {
            _ = store.hudVisible
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.setVisible(self.store.hudVisible)
                self.startObserving()
            }
        }
    }

    private func restorePosition() {
        if let origin = Preferences.hudOrigin, origin != .zero {
            panel.setFrameOrigin(origin)
            return
        }
        guard let screen = NSScreen.main?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: screen.maxX - size.width - 16,
            y: screen.maxY - size.height - 14
        )
        panel.setFrameOrigin(origin)
    }

    @objc private func windowMoved(_ notification: Notification) {
        Preferences.hudOrigin = panel.frame.origin
    }
}

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
