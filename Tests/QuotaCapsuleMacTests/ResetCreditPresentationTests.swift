@testable import QuotaCapsuleMac
import Foundation
import QuotaCapsuleCore
import Testing

@Suite("Reset credit footer presentation")
struct ResetCreditPresentationTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("only available credits render in expiry order without identity leakage")
    func availableRowsAreSafeAndSorted() throws {
        let timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let early = credit("early", status: .available, expiryOffset: 60)
        let late = credit("late", status: .available, expiryOffset: 120)
        let redeemed = credit("redeemed", status: .redeemed, expiryOffset: 30)
        let bank = ResetCreditBankSummary(
            availableCount: 4,
            credits: [late, redeemed, early],
            detailState: .capped,
            fetchedAt: now
        )

        let presentation = ResetCreditPresentation.make(
            bank: bank,
            copy: QuotaCopy(locale: .zhHans),
            timeZone: timeZone
        )

        #expect(presentation.rows.map(\.id) == ["early", "late"])
        #expect(presentation.rows.allSatisfy { !$0.text.contains($0.id) })
        #expect(presentation.missingDetailsText == "另有 2 张未返回到期详情")
    }

    @Test("count-only and explicit zero banks remain distinct")
    func countOnlyAndZeroAreDistinct() {
        let copy = QuotaCopy(locale: .zhHans)
        let countOnly = ResetCreditPresentation.make(
            bank: ResetCreditBankSummary(availableCount: 3, credits: nil, detailState: .countOnly, fetchedAt: now),
            copy: copy,
            timeZone: .current
        )
        let zero = ResetCreditPresentation.make(
            bank: ResetCreditBankSummary(availableCount: 0, credits: [], detailState: .complete, fetchedAt: now),
            copy: copy,
            timeZone: .current
        )

        #expect(countOnly.countText == "3 张重置券可用")
        #expect(countOnly.rows.isEmpty)
        #expect(countOnly.missingDetailsText == "暂未返回每张券的到期详情")
        #expect(zero.countText == "暂无可用重置券")
        #expect(zero.missingDetailsText == nil)
    }

    private func credit(_ fingerprint: String, status: ResetCreditStatus, expiryOffset: TimeInterval) -> ResetCredit {
        ResetCredit(
            fingerprint: fingerprint,
            resetType: "codexRateLimits",
            status: status,
            grantedAt: nil,
            grantTimeSource: .unknown,
            expiresAt: now.addingTimeInterval(expiryOffset),
            title: nil
        )
    }
}
