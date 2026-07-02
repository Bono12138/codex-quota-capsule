import SwiftUI
import AppKit
import QuartzCore
import Combine

private enum EdgeHiddenState {
    case left
    case right

    var analyticsValue: String {
        switch self {
        case .left: "left"
        case .right: "right"
        }
    }
}

@MainActor
final class CapsulePanelController {
    private let panel: NSPanel
    private let store: QuotaStore
    private var dragStartOrigin: NSPoint?
    private var dragStartMouseLocation: NSPoint?
    private var hiddenEdge: EdgeHiddenState?
    private var isResizeInProgress = false
    private var visibleStartedAt: Date?
    private var cancellables: Set<AnyCancellable> = []
    private let collapsedHeight: CGFloat = CapsuleViewMetrics.collapsedHeight
    private let expandedHeight: CGFloat = CapsuleViewMetrics.expandedHeight
    private let dockedWidth: CGFloat = CapsuleViewMetrics.dockedWidth
    private let dockedHeight: CGFloat = CapsuleViewMetrics.dockedHeight
    private let edgeSnapThreshold: CGFloat = 18
    private let edgeMargin: CGFloat = 12
    private let dockedEdgeInset: CGFloat = 4

    init(store: QuotaStore) {
        self.store = store
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: store.capsuleWidth + CapsuleViewMetrics.shadowPadding * 2, height: collapsedHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.panel = panel
        let hostingView = TransparentHostingView(rootView: CapsuleRootView(store: store))
        hostingView.onPrimaryClick = { [weak self] in
            self?.handlePrimaryClick()
        }
        hostingView.onPanelDragged = { [weak self] mouseLocation in
            self?.movePanel(to: mouseLocation)
        }
        hostingView.onPanelDragEnded = { [weak self] in
            self?.finishMovingPanel()
        }
        hostingView.onResizeStarted = { [weak self] in
            self?.handleResizeStarted()
        }
        hostingView.onResizeChanged = { [weak self] targetWidth in
            self?.handleResizeChanged(targetWidth)
        }
        hostingView.onResizeEnded = { [weak self] in
            self?.handleResizeEnded()
        }
        hostingView.configureTransparentBacking()
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        placeNearTopRight()
        bindStore()
    }

    func show() {
        let wasVisible = panel.isVisible
        placeNearTopRightIfNeeded()
        panel.orderFrontRegardless()
        if !wasVisible {
            visibleStartedAt = Date()
            store.recordCapsuleVisibility(visible: true)
        }
    }

    func toggle() {
        if panel.isVisible {
            let duration = visibleStartedAt.map { Date().timeIntervalSince($0) }
            visibleStartedAt = nil
            store.recordCapsuleVisibility(visible: false, durationSeconds: duration)
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func setExpanded(_ expanded: Bool) {
        revealDockedCapsuleIfNeeded()
        store.setPanelExpanded(expanded, surface: "onboarding")
        resizeForCurrentState()
        show()
    }

    private func placeNearTopRightIfNeeded() {
        if panel.frame.origin == .zero {
            placeNearTopRight()
        }
    }

    private func placeNearTopRight() {
        guard let screen = NSScreen.currentPlacementScreen else {
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

    private func bindStore() {
        store.$capsuleWidth
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.resizeForCurrentState()
            }
            .store(in: &cancellables)

        store.$isPanelExpanded
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.resizeForCurrentState()
            }
            .store(in: &cancellables)
    }

    private func resizeForCurrentState() {
        Self.resize(
            panel: panel,
            width: currentPanelWidth,
            height: currentPanelHeight
        )
    }

    private var currentPanelWidth: CGFloat {
        hiddenEdge == nil && !store.isCapsuleDocked ? store.capsuleWidth + CapsuleViewMetrics.shadowPadding * 2 : dockedWidth
    }

    private var currentPanelHeight: CGFloat {
        if hiddenEdge != nil || store.isCapsuleDocked {
            return dockedHeight
        }
        return store.isPanelExpanded ? expandedHeight : collapsedHeight
    }

    private static func resize(panel: NSPanel, width: CGFloat, height: CGFloat) {
        let oldFrame = panel.frame
        let newFrame = NSRect(
            x: oldFrame.origin.x,
            y: oldFrame.maxY - height,
            width: width,
            height: height
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrame(newFrame, display: true, animate: false)
        panel.displayIfNeeded()
        CATransaction.commit()
    }

    private func handlePrimaryClick() {
        if hiddenEdge != nil || store.isCapsuleDocked {
            revealDockedCapsuleIfNeeded()
            setExpandedFromCapsule(true)
            return
        }
        setExpandedFromCapsule(!store.isPanelExpanded)
    }

    private func setExpandedFromCapsule(_ expanded: Bool) {
        store.setPanelExpanded(expanded)
        resizeForCurrentState()
    }

    private func handleResizeStarted() {
        isResizeInProgress = true
        dragStartOrigin = nil
        dragStartMouseLocation = nil
    }

    private func handleResizeChanged(_ targetWidth: CGFloat) {
        store.setCapsuleWidth(targetWidth)
    }

    private func handleResizeEnded() {
        isResizeInProgress = false
        store.setCapsuleWidth(store.capsuleWidth, commit: true)
        clampPanelToVisibleArea()
    }

    private func movePanel(to currentMouse: NSPoint) {
        guard !isResizeInProgress else {
            return
        }
        revealDockedCapsuleIfNeeded()
        if dragStartOrigin == nil {
            dragStartOrigin = panel.frame.origin
            dragStartMouseLocation = currentMouse
        }

        guard let start = dragStartOrigin,
              let startMouse = dragStartMouseLocation else {
            return
        }

        let deltaX = currentMouse.x - startMouse.x
        let deltaY = currentMouse.y - startMouse.y

        panel.setFrameOrigin(
            NSPoint(
                x: start.x + deltaX,
                y: start.y + deltaY
            )
        )
    }

    private func finishMovingPanel() {
        dragStartOrigin = nil
        dragStartMouseLocation = nil
        snapToEdgeIfNeeded()
    }

    private func snapToEdgeIfNeeded() {
        guard let visible = activeScreen()?.visibleFrame else {
            return
        }

        var frame = panel.frame
        frame.origin.y = clampedY(frame.origin.y, height: frame.height, visible: visible)

        if frame.minX <= visible.minX + edgeSnapThreshold {
            dockCapsule(edge: .left, visible: visible, y: frame.origin.y)
            return
        }

        if frame.maxX >= visible.maxX - edgeSnapThreshold {
            dockCapsule(edge: .right, visible: visible, y: frame.origin.y)
            return
        }

        hiddenEdge = nil
        store.setCapsuleDocked(false)
        panel.setFrameOrigin(clampedOrigin(for: frame, visible: visible))
    }

    private func dockCapsule(edge: EdgeHiddenState, visible: NSRect, y: CGFloat) {
        if store.isPanelExpanded {
            store.setPanelExpanded(false)
        }
        hiddenEdge = edge
        store.setCapsuleDocked(true)
        resizeForCurrentState()
        let frame = panel.frame
        let originX: CGFloat
        switch edge {
        case .left:
            originX = visible.minX + dockedEdgeInset
        case .right:
            originX = visible.maxX - frame.width - dockedEdgeInset
        }
        panel.setFrameOrigin(
            NSPoint(
                x: originX,
                y: clampedY(y, height: frame.height, visible: visible)
            )
        )
        store.recordCapsuleEdgeHidden(edge.analyticsValue)
    }

    private func revealDockedCapsuleIfNeeded() {
        guard hiddenEdge != nil || store.isCapsuleDocked,
              let visible = activeScreen()?.visibleFrame else {
            return
        }

        let edge = hiddenEdge ?? (panel.frame.midX < visible.midX ? EdgeHiddenState.left : .right)
        hiddenEdge = nil
        store.setCapsuleDocked(false)
        resizeForCurrentState()
        let frame = panel.frame
        let originX: CGFloat
        switch edge {
        case .left:
            originX = visible.minX + edgeMargin
        case .right:
            originX = visible.maxX - frame.width - edgeMargin
        }
        panel.setFrameOrigin(
            NSPoint(
                x: originX,
                y: clampedY(frame.origin.y, height: frame.height, visible: visible)
            )
        )
        store.recordCapsuleEdgeRevealed(edge.analyticsValue)
    }

    private func clampPanelToVisibleArea() {
        guard let visible = activeScreen()?.visibleFrame else {
            return
        }
        panel.setFrameOrigin(clampedOrigin(for: panel.frame, visible: visible))
    }

    private func clampedOrigin(for frame: NSRect, visible: NSRect) -> NSPoint {
        let minX = visible.minX + edgeMargin
        let maxX = max(minX, visible.maxX - frame.width - edgeMargin)
        return NSPoint(
            x: min(max(frame.origin.x, minX), maxX),
            y: clampedY(frame.origin.y, height: frame.height, visible: visible)
        )
    }

    private func clampedY(_ y: CGFloat, height: CGFloat, visible: NSRect) -> CGFloat {
        let minY = visible.minY + edgeMargin
        let maxY = max(minY, visible.maxY - height - edgeMargin)
        return min(max(y, minY), maxY)
    }

    private func activeScreen() -> NSScreen? {
        panel.screen ?? NSScreen.bestScreen(for: panel.frame) ?? NSScreen.currentPlacementScreen
    }
}

extension NSScreen {
    static var currentPlacementScreen: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens.first
    }

    static func bestScreen(for frame: NSRect) -> NSScreen? {
        NSScreen.screens.max { first, second in
            first.frame.intersection(frame).area < second.frame.intersection(frame).area
        }
    }
}

private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    var onMouseEntered: (() -> Void)?
    var onPrimaryClick: (() -> Void)?
    var onPanelDragged: ((NSPoint) -> Void)?
    var onPanelDragEnded: (() -> Void)?
    var onResizeStarted: (() -> Void)?
    var onResizeChanged: ((CGFloat) -> Void)?
    var onResizeEnded: (() -> Void)?
    private var hoverTrackingArea: NSTrackingArea?
    private var mouseDownLocation: NSPoint?
    private var isPanelDragging = false
    private var activeMouseMode: MouseMode?
    private var resizeStartMouseX: CGFloat?
    private var resizeStartWidth: CGFloat?

    private enum MouseMode {
        case moveOrClick
        case resize
    }

    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    required init(rootView: Content) {
        super.init(rootView: rootView)
        configureTransparentBacking()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureTransparentBacking() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layer?.masksToBounds = false
        layer?.shadowOpacity = 0
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureTransparentBacking()
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }

    override func updateTrackingAreas() {
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if shouldStartResize(at: point) {
            activeMouseMode = .resize
            resizeStartMouseX = NSEvent.mouseLocation.x
            resizeStartWidth = max(
                0,
                bounds.width - CapsuleViewMetrics.shadowPadding * 2
            )
            onResizeStarted?()
            return
        }

        activeMouseMode = .moveOrClick
        mouseDownLocation = NSEvent.mouseLocation
        isPanelDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        if activeMouseMode == .resize {
            guard let resizeStartMouseX,
                  let resizeStartWidth else {
                return
            }
            let deltaX = NSEvent.mouseLocation.x - resizeStartMouseX
            let steppedWidth = ((resizeStartWidth + deltaX) / 2).rounded() * 2
            onResizeChanged?(steppedWidth)
            return
        }

        guard activeMouseMode == .moveOrClick else {
            return
        }

        guard let start = mouseDownLocation else {
            return
        }

        let current = NSEvent.mouseLocation
        let distance = hypot(current.x - start.x, current.y - start.y)
        guard isPanelDragging || distance >= 8 else {
            return
        }

        isPanelDragging = true
        onPanelDragged?(current)
    }

    override func mouseUp(with event: NSEvent) {
        if activeMouseMode == .resize {
            activeMouseMode = nil
            resizeStartMouseX = nil
            resizeStartWidth = nil
            onResizeEnded?()
            return
        }

        defer {
            activeMouseMode = nil
            mouseDownLocation = nil
            isPanelDragging = false
        }

        if isPanelDragging {
            onPanelDragEnded?()
        } else {
            onPrimaryClick?()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    private func shouldStartResize(at point: NSPoint) -> Bool {
        guard bounds.width > CapsuleViewMetrics.dockedWidth + 30 else {
            return false
        }
        return point.x >= bounds.maxX - 42 && point.y >= bounds.maxY - 72
    }
}

private extension NSRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else {
            return 0
        }
        return width * height
    }
}
