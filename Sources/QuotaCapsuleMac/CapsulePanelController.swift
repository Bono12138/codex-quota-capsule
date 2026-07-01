import SwiftUI
import AppKit
import QuartzCore

@MainActor
final class CapsulePanelController {
    private let panel: NSPanel
    private var dragStartOrigin: NSPoint?
    private var dragStartMouseLocation: NSPoint?

    init(store: QuotaStore) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 78),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.panel = panel
        panel.contentView = NSHostingView(
            rootView: CapsuleRootView(
                store: store,
                onExpandedChanged: { [weak panel] expanded in
                    guard let panel else { return }
                    let newSize = NSSize(width: 380, height: expanded ? 470 : 78)
                    let oldFrame = panel.frame
                    let newFrame = NSRect(
                        x: oldFrame.origin.x,
                        y: oldFrame.maxY - newSize.height,
                        width: newSize.width,
                        height: newSize.height
                    )
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    panel.setFrame(newFrame, display: true, animate: false)
                    panel.displayIfNeeded()
                    CATransaction.commit()
                },
                onDragChanged: { [weak self] translation in
                    self?.movePanel(translation: translation)
                },
                onDragEnded: { [weak self] in
                    self?.dragStartOrigin = nil
                    self?.dragStartMouseLocation = nil
                }
            )
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
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

    private func movePanel(translation: CGSize) {
        if dragStartOrigin == nil {
            dragStartOrigin = panel.frame.origin
            dragStartMouseLocation = NSEvent.mouseLocation
        }

        guard let start = dragStartOrigin,
              let startMouse = dragStartMouseLocation else {
            return
        }

        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - startMouse.x
        let deltaY = currentMouse.y - startMouse.y

        panel.setFrameOrigin(
            NSPoint(
                x: start.x + deltaX,
                y: start.y + deltaY
            )
        )
    }
}
