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

private enum CapsuleResizeEdge {
    case leading
    case trailing
}

@MainActor
final class CapsulePanelController {
    private let panel: NSPanel
    private let store: QuotaStore
    private var dragStartOrigin: NSPoint?
    private var dragStartMouseLocation: NSPoint?
    private var dragStartFrame: NSRect?
    private var hiddenEdge: EdgeHiddenState?
    private var isResizeInProgress = false
    private var resizeEdge: CapsuleResizeEdge?
    private var resizeStartFrame: NSRect?
    private var visibleStartedAt: Date?
    private var cancellables: Set<AnyCancellable> = []
    private let collapsedHeight: CGFloat = CapsuleViewMetrics.collapsedHeight
    private let expandedHeight: CGFloat = CapsuleViewMetrics.expandedHeight
    private let dockedWidth: CGFloat = CapsuleViewMetrics.dockedWidth
    private let dockedHeight: CGFloat = CapsuleViewMetrics.dockedHeight
    private let edgeSnapThreshold: CGFloat = 18
    private let edgeMargin: CGFloat = 12
    private let dockedEdgeInset: CGFloat = 4
    private let edgeDockPushDistance: CGFloat = 16

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
        hostingView.onResizeStarted = { [weak self] edge in
            self?.handleResizeStarted(edge)
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
                guard let self, !self.isResizeInProgress else { return }
                self.resizeForCurrentState()
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

    private static func resize(panel: NSPanel, width: CGFloat, height: CGFloat, originX: CGFloat? = nil) {
        let oldFrame = panel.frame
        let newFrame = NSRect(
            x: originX ?? oldFrame.origin.x,
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

    private func handleResizeStarted(_ edge: CapsuleResizeEdge) {
        isResizeInProgress = true
        resizeEdge = edge
        resizeStartFrame = panel.frame
        dragStartOrigin = nil
        dragStartMouseLocation = nil
    }

    private func handleResizeChanged(_ targetWidth: CGFloat) {
        store.setCapsuleWidth(targetWidth)
        let originX: CGFloat?
        if resizeEdge == .leading, let resizeStartFrame {
            originX = resizeStartFrame.maxX - currentPanelWidth
        } else {
            originX = nil
        }
        Self.resize(
            panel: panel,
            width: currentPanelWidth,
            height: currentPanelHeight,
            originX: originX
        )
    }

    private func handleResizeEnded() {
        isResizeInProgress = false
        resizeEdge = nil
        resizeStartFrame = nil
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
            dragStartFrame = panel.frame
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
        let startFrame = dragStartFrame
        dragStartOrigin = nil
        dragStartMouseLocation = nil
        dragStartFrame = nil
        snapToEdgeIfNeeded(startFrame: startFrame)
    }

    private func snapToEdgeIfNeeded(startFrame: NSRect?) {
        guard let visible = activeScreen()?.visibleFrame else {
            return
        }

        var frame = panel.frame
        frame.origin.y = clampedY(frame.origin.y, height: frame.height, visible: visible)

        if shouldDockLeft(frame: frame, visible: visible, startFrame: startFrame) {
            dockCapsule(edge: .left, visible: visible, y: frame.origin.y)
            return
        }

        if shouldDockRight(frame: frame, visible: visible, startFrame: startFrame) {
            dockCapsule(edge: .right, visible: visible, y: frame.origin.y)
            return
        }

        hiddenEdge = nil
        store.setCapsuleDocked(false)
        panel.setFrameOrigin(clampedOrigin(for: frame, visible: visible))
    }

    private func shouldDockLeft(frame: NSRect, visible: NSRect, startFrame: NSRect?) -> Bool {
        guard frame.minX <= visible.minX + edgeSnapThreshold else {
            return false
        }
        guard let startFrame else {
            return true
        }
        let startedNearEdge = startFrame.minX <= visible.minX + edgeSnapThreshold
        guard startedNearEdge else {
            return true
        }
        return frame.minX <= visible.minX - 4 || startFrame.minX - frame.minX >= edgeDockPushDistance
    }

    private func shouldDockRight(frame: NSRect, visible: NSRect, startFrame: NSRect?) -> Bool {
        guard frame.maxX >= visible.maxX - edgeSnapThreshold else {
            return false
        }
        guard let startFrame else {
            return true
        }
        let startedNearEdge = startFrame.maxX >= visible.maxX - edgeSnapThreshold
        guard startedNearEdge else {
            return true
        }
        return frame.maxX >= visible.maxX + 4 || frame.maxX - startFrame.maxX >= edgeDockPushDistance
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
    var onResizeStarted: ((CapsuleResizeEdge) -> Void)?
    var onResizeChanged: ((CGFloat) -> Void)?
    var onResizeEnded: (() -> Void)?
    private var hoverTrackingArea: NSTrackingArea?
    private var mouseDownLocation: NSPoint?
    private var isPanelDragging = false
    private var activeMouseMode: MouseMode?
    private var pendingResizeEdge: CapsuleResizeEdge?
    private var activeResizeEdge: CapsuleResizeEdge?
    private var resizeStartMouseX: CGFloat?
    private var resizeStartWidth: CGFloat?
    private var dragActivationDistance: CGFloat { 12 }
    private var resizeActivationDistance: CGFloat { 12 }
    private var resizeHitWidth: CGFloat { 42 }

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

    override func resetCursorRects() {
        super.resetCursorRects()
        for rect in resizeCursorRects {
            addCursorRect(rect, cursor: .resizeLeftRight)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard shouldHandlePanelInteraction(at: point) else {
            super.mouseDown(with: event)
            return
        }

        activeMouseMode = .moveOrClick
        mouseDownLocation = NSEvent.mouseLocation
        pendingResizeEdge = resizeEdge(at: point)
        resizeStartMouseX = NSEvent.mouseLocation.x
        resizeStartWidth = max(
            0,
            bounds.width - CapsuleViewMetrics.shadowPadding * 2
        )
        isPanelDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard activeMouseMode != nil else {
            super.mouseDragged(with: event)
            return
        }

        if activeMouseMode == .resize {
            guard let resizeStartMouseX,
                  let resizeStartWidth,
                  let activeResizeEdge else {
                return
            }
            let deltaX = NSEvent.mouseLocation.x - resizeStartMouseX
            let rawWidth: CGFloat
            switch activeResizeEdge {
            case .leading:
                rawWidth = resizeStartWidth - deltaX
            case .trailing:
                rawWidth = resizeStartWidth + deltaX
            }
            let steppedWidth = (rawWidth / 2).rounded() * 2
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
        let deltaX = current.x - start.x
        let deltaY = current.y - start.y
        let distance = hypot(current.x - start.x, current.y - start.y)

        if let pendingResizeEdge,
           !isPanelDragging,
           distance >= resizeActivationDistance,
           abs(deltaX) >= max(6, abs(deltaY) * 1.2),
           let resizeStartMouseX,
           let resizeStartWidth {
            activeMouseMode = .resize
            activeResizeEdge = pendingResizeEdge
            onResizeStarted?(pendingResizeEdge)
            let rawWidth: CGFloat
            switch pendingResizeEdge {
            case .leading:
                rawWidth = resizeStartWidth - (NSEvent.mouseLocation.x - resizeStartMouseX)
            case .trailing:
                rawWidth = resizeStartWidth + (NSEvent.mouseLocation.x - resizeStartMouseX)
            }
            onResizeChanged?((rawWidth / 2).rounded() * 2)
            return
        }

        guard isPanelDragging || distance >= dragActivationDistance else {
            return
        }

        isPanelDragging = true
        onPanelDragged?(current)
    }

    override func mouseUp(with event: NSEvent) {
        guard activeMouseMode != nil else {
            super.mouseUp(with: event)
            return
        }

        if activeMouseMode == .resize {
            activeMouseMode = nil
            pendingResizeEdge = nil
            activeResizeEdge = nil
            mouseDownLocation = nil
            isPanelDragging = false
            resizeStartMouseX = nil
            resizeStartWidth = nil
            onResizeEnded?()
            return
        }

        defer {
            activeMouseMode = nil
            mouseDownLocation = nil
            isPanelDragging = false
            pendingResizeEdge = nil
            activeResizeEdge = nil
            resizeStartMouseX = nil
            resizeStartWidth = nil
        }

        if isPanelDragging {
            onPanelDragEnded?()
        } else {
            onPrimaryClick?()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else {
            return nil
        }

        if shouldHandlePanelInteraction(at: point) {
            return self
        }

        return super.hitTest(point)
    }

    private var resizeCursorRects: [NSRect] {
        guard bounds.width > CapsuleViewMetrics.dockedWidth + 30 else {
            return []
        }
        return [
            NSRect(x: bounds.minX, y: capsuleChromeRect.minY, width: resizeHitWidth, height: capsuleChromeRect.height),
            NSRect(x: bounds.maxX - resizeHitWidth, y: capsuleChromeRect.minY, width: resizeHitWidth, height: capsuleChromeRect.height)
        ]
    }

    private func resizeEdge(at point: NSPoint) -> CapsuleResizeEdge? {
        guard bounds.width > CapsuleViewMetrics.dockedWidth + 30 else {
            return nil
        }
        guard capsuleChromeRect.contains(point) else {
            return nil
        }
        if point.x <= bounds.minX + resizeHitWidth {
            return .leading
        }
        if point.x >= bounds.maxX - resizeHitWidth {
            return .trailing
        }
        return nil
    }

    private func shouldHandlePanelInteraction(at point: NSPoint) -> Bool {
        if bounds.width <= CapsuleViewMetrics.dockedWidth + 30 {
            return true
        }

        return capsuleChromeRect.contains(point)
    }

    private var capsuleChromeRect: NSRect {
        let topBandHeight = min(
            bounds.height,
            CapsuleViewMetrics.shadowPadding + CapsuleViewMetrics.collapsedContentHeight + 8
        )
        let originY = isFlipped ? bounds.minY : bounds.maxY - topBandHeight
        return NSRect(
            x: bounds.minX,
            y: originY,
            width: bounds.width,
            height: topBandHeight
        )
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
