@testable import QuotaCapsuleMac
import Testing

@Suite("Status bar update gate")
struct StatusBarPresentationTests {
    @Test("identical clock-tick presentations do not rebuild")
    func identicalPresentationsAreDeduplicated() {
        var gate = StatusBarUpdateGate<String>()
        #expect(gate.receive("stable") == "stable")
        for _ in 0..<10 {
            #expect(gate.receive("stable") == nil)
        }
    }

    @Test("tracking coalesces changes and applies the latest once")
    func trackingDefersLatestPresentation() {
        var gate = StatusBarUpdateGate<String>()
        #expect(gate.receive("initial") == "initial")
        gate.beginTracking()
        #expect(gate.receive("first") == nil)
        #expect(gate.receive("latest") == nil)
        #expect(gate.endTracking() == "latest")
        #expect(gate.endTracking() == nil)
    }

    @Test("tracking reversion cancels a stale pending rebuild")
    func trackingReversionCancelsPendingValue() {
        var gate = StatusBarUpdateGate<String>()
        #expect(gate.receive("initial") == "initial")
        gate.beginTracking()
        #expect(gate.receive("temporary") == nil)
        #expect(gate.receive("initial") == nil)
        #expect(gate.endTracking() == nil)
    }
}
