import SwiftUI
import AppKit

@MainActor
final class CapsulePanelController {
    private let panel: NSPanel

    init(store: QuotaStore) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 78),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(
            rootView: CapsuleRootView(store: store) { [weak panel] expanded in
                guard let panel else { return }
                let newSize = NSSize(width: 380, height: expanded ? 355 : 78)
                let oldFrame = panel.frame
                let newFrame = NSRect(
                    x: oldFrame.origin.x,
                    y: oldFrame.maxY - newSize.height,
                    width: newSize.width,
                    height: newSize.height
                )
                panel.setFrame(newFrame, display: true, animate: true)
            }
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        self.panel = panel
        placeNearTopRight()
    }

    func show() {
        placeNearTopRightIfNeeded()
        panel.orderFrontRegardless()
    }

    func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    private func placeNearTopRightIfNeeded() {
        if panel.frame.origin == .zero {
            placeNearTopRight()
        }
    }

    private func placeNearTopRight() {
        guard let screen = NSScreen.main else {
            return
        }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.maxX - size.width - 24,
            y: visible.maxY - size.height - 24
        )
        panel.setFrameOrigin(origin)
    }
}
