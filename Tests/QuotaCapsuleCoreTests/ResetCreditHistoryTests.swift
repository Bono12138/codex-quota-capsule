@testable import QuotaCapsuleCore
import Foundation
import Testing

@Suite("Reset credit lifecycle")
struct ResetCreditHistoryTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("a disappearance after expiry is expired")
    func expiredDisappearance() {
        #expect(ResetCreditLifecycleClassifier.classifyDisappearance(
            expiresAt: now.addingTimeInterval(-1),
            observedAt: now,
            compatibleResetConfirmed: false
        ) == .expired)
    }

    @Test("a pre-expiry disappearance needs reset confirmation")
    func earlyDisappearanceIsConservative() {
        let expiry = now.addingTimeInterval(86_400)
        #expect(ResetCreditLifecycleClassifier.classifyDisappearance(
            expiresAt: expiry,
            observedAt: now,
            compatibleResetConfirmed: false
        ) == .disappearedUnknown)
        #expect(ResetCreditLifecycleClassifier.classifyDisappearance(
            expiresAt: expiry,
            observedAt: now,
            compatibleResetConfirmed: true
        ) == .likelyRedeemed)
    }
}
