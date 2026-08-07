@testable import QuotaCapsuleMac
import AppKit
import Testing

@Suite("Capsule panel placement")
struct CapsulePanelPlacementTests {
    @Test("showing a capsule from a disconnected screen returns it to the current screen")
    func disconnectedScreenFrameIsRecovered() {
        let currentScreen = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let oldScreenFrame = NSRect(x: 2_000, y: 300, width: 440, height: 92)

        let visible = CapsulePanelPlacement.visibleFrame(
            for: oldScreenFrame,
            available: [currentScreen],
            preferred: currentScreen
        )
        let origin = CapsulePanelPlacement.clampedOrigin(
            for: oldScreenFrame,
            visible: visible!,
            margin: 12
        )

        #expect(visible == currentScreen)
        #expect(origin == NSPoint(x: 988, y: 300))
    }

    @Test("a capsule keeps using the screen where it is already visible")
    func visibleFrameKeepsItsScreen() {
        let main = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let secondary = NSRect(x: 1_440, y: 0, width: 1_280, height: 800)
        let frame = NSRect(x: 1_900, y: 500, width: 440, height: 92)

        let visible = CapsulePanelPlacement.visibleFrame(
            for: frame,
            available: [main, secondary],
            preferred: main
        )

        #expect(visible == secondary)
    }
}
