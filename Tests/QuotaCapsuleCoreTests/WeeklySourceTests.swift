@testable import QuotaCapsuleCore
import Foundation
import Testing

@Suite("Weekly source parsing")
struct WeeklySourceTests {
    private let now = Date(timeIntervalSince1970: 1_789_000_000)

    @Test("the source snapshot API is weekly only")
    func sourceSnapshotAPIIsWeeklyOnly() {
        let snapshot = AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .ok,
            fetchedAt: now,
            weeklyWindow: QuotaWindow(
                label: "weekly",
                windowMinutes: 10_080,
                usedPercent: 18,
                remainingPercent: 82,
                resetsAt: now.addingTimeInterval(500_000)
            ),
            errorMessage: nil
        )

        #expect(snapshot.weeklyWindow?.remainingPercent == 82)
    }

    @Test("a fresh weekly snapshot does not retry")
    func freshWeeklySnapshotDoesNotRetry() {
        let snapshot = AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .ok,
            fetchedAt: now,
            weeklyWindow: QuotaWindow(
                label: "weekly",
                windowMinutes: 10_080,
                usedPercent: 18,
                remainingPercent: 82,
                resetsAt: now.addingTimeInterval(500_000)
            ),
            errorMessage: nil
        )

        #expect(CodexAppServerClient.shouldRetry(snapshot) == false)
    }

    @Test("the weekly candidate is selected from mixed source data")
    func parserSelectsWeeklyCandidate() {
        let snapshot = CodexRateLimitParser.parse(
            result: [
                "rateLimits": [
                    "primary": window(used: 41, minutes: 300, resetOffset: 3_600),
                    "secondary": window(used: 18, minutes: 10_080, resetOffset: 500_000)
                ]
            ],
            fetchedAt: now
        )

        #expect(snapshot.sourceStatus == .ok)
        #expect(snapshot.weeklyWindow?.usedPercent == 18)
        #expect(snapshot.weeklyWindow?.windowMinutes == 10_080)
    }

    @Test("a payload without a weekly window is unavailable")
    func parserRejectsPayloadWithoutWeeklyWindow() {
        let snapshot = CodexRateLimitParser.parse(
            result: [
                "rateLimits": [
                    "primary": window(used: 10, minutes: 300, resetOffset: 3_600)
                ]
            ],
            fetchedAt: now
        )

        #expect(snapshot.sourceStatus == .error)
        #expect(snapshot.weeklyWindow == nil)
    }

    @Test("an arbitrary long window is not treated as weekly")
    func parserRejectsNonWeeklyLongWindow() {
        let snapshot = CodexRateLimitParser.parse(
            result: [
                "rateLimits": [
                    "primary": window(used: 10, minutes: 1_440, resetOffset: 80_000)
                ]
            ],
            fetchedAt: now
        )

        #expect(snapshot.sourceStatus == .error)
        #expect(snapshot.weeklyWindow == nil)
    }

    @Test("an expired weekly reset is rejected")
    func parserRejectsExpiredWeeklyReset() {
        let snapshot = CodexRateLimitParser.parse(
            result: [
                "rateLimits": [
                    "primary": window(used: 10, minutes: 10_080, resetOffset: -60)
                ]
            ],
            fetchedAt: now
        )

        #expect(snapshot.sourceStatus == .error)
        #expect(snapshot.weeklyWindow == nil)
    }

    private func window(used: Double, minutes: Int, resetOffset: TimeInterval) -> [String: Any] {
        [
            "usedPercent": used,
            "windowDurationMins": minutes,
            "resetsAt": now.addingTimeInterval(resetOffset).timeIntervalSince1970
        ]
    }
}
