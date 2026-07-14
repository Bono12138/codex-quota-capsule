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

    @Test("reset credit details preserve count, nullable expiry, and safe identity")
    func parserReadsResetCreditBank() throws {
        let snapshot = CodexRateLimitParser.parse(
            result: [
                "rateLimits": ["primary": window(used: 18, minutes: 10_080, resetOffset: 500_000)],
                "rateLimitResetCredits": [
                    "availableCount": 3,
                    "credits": [
                        [
                            "id": "fake-credit-a",
                            "resetType": "codexRateLimits",
                            "status": "available",
                            "grantedAt": now.timeIntervalSince1970 - 86_400,
                            "expiresAt": now.timeIntervalSince1970 + 86_400,
                            "title": "  Full reset  ",
                            "description": "must be ignored"
                        ],
                        [
                            "id": "fake-credit-b",
                            "resetType": "codexRateLimits",
                            "status": "unknown",
                            "grantedAt": now.timeIntervalSince1970 - 43_200,
                            "expiresAt": NSNull(),
                            "title": NSNull(),
                            "description": NSNull()
                        ]
                    ]
                ]
            ],
            fetchedAt: now
        )

        let bank = try #require(snapshot.resetCreditBank)
        #expect(bank.availableCount == 3)
        #expect(bank.fetchedAt == now)
        #expect(bank.detailState == .capped)
        #expect(bank.credits?.count == 2)
        #expect(bank.credits?.first?.fingerprint.count == 64)
        #expect(bank.credits?.first?.fingerprint != "fake-credit-a")
        #expect(bank.credits?.first?.title == "Full reset")
        #expect(bank.credits?.last?.expiresAt == nil)
    }

    @Test("reset credit detail absence is distinct from an empty complete bank")
    func parserDistinguishesCountOnlyAndEmptyDetails() throws {
        let countOnly = CodexRateLimitParser.parse(
            result: resetCreditPayload(availableCount: 2, credits: NSNull()),
            fetchedAt: now
        )
        let empty = CodexRateLimitParser.parse(
            result: resetCreditPayload(availableCount: 0, credits: []),
            fetchedAt: now
        )

        #expect(countOnly.resetCreditBank?.detailState == .countOnly)
        #expect(countOnly.resetCreditBank?.credits == nil)
        #expect(empty.resetCreditBank?.detailState == .complete)
        #expect(empty.resetCreditBank?.credits == [])
    }

    @Test("nullable grant time is retained but malformed timestamps reject only their rows")
    func parserValidatesResetCreditTimesPerRow() throws {
        let snapshot = CodexRateLimitParser.parse(
            result: resetCreditPayload(
                availableCount: 3,
                credits: [
                    [
                        "id": "fake-no-grant",
                        "resetType": "codexRateLimits",
                        "status": "available",
                        "grantedAt": NSNull(),
                        "expiresAt": now.timeIntervalSince1970 + 90_000
                    ],
                    [
                        "id": "fake-bad-grant",
                        "resetType": "codexRateLimits",
                        "status": "available",
                        "grantedAt": "not-a-time",
                        "expiresAt": now.timeIntervalSince1970 + 100_000
                    ],
                    [
                        "id": "fake-bad-expiry",
                        "resetType": "codexRateLimits",
                        "status": "available",
                        "grantedAt": now.timeIntervalSince1970,
                        "expiresAt": -1
                    ]
                ]
            ),
            fetchedAt: now
        )

        let bank = try #require(snapshot.resetCreditBank)
        #expect(bank.credits?.count == 1)
        #expect(bank.credits?.first?.grantedAt == nil)
        #expect(bank.credits?.first?.grantTimeSource == .unknown)
        #expect(bank.detailState == .capped)
    }

    @Test("a missing reset credit bank stays absent")
    func parserKeepsMissingResetCreditBankAbsent() {
        let snapshot = CodexRateLimitParser.parse(
            result: ["rateLimits": ["primary": window(used: 18, minutes: 10_080, resetOffset: 500_000)]],
            fetchedAt: now
        )

        #expect(snapshot.resetCreditBank == nil)
    }

    @Test("a failed refresh preserves the last accepted reset credit bank")
    func staleReducerPreservesResetCreditBank() {
        let bank = ResetCreditBankSummary(
            availableCount: 2,
            credits: nil,
            detailState: .countOnly,
            fetchedAt: now
        )
        let current = AgentQuotaSnapshot(
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
            resetCreditBank: bank,
            errorMessage: nil
        )
        let failure = AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .error,
            fetchedAt: now.addingTimeInterval(60),
            weeklyWindow: nil,
            errorMessage: "temporary failure"
        )

        let reduced = QuotaRefreshReducer.reduce(
            currentSnapshot: current,
            currentLastRefreshText: "10:00",
            newSnapshot: failure,
            now: failure.fetchedAt,
            attemptText: "10:01"
        )

        #expect(reduced.snapshot.sourceStatus == .stale)
        #expect(reduced.snapshot.resetCreditBank == bank)
        #expect(reduced.latestAttemptSnapshot.resetCreditBank == nil)
    }

    private func window(used: Double, minutes: Int, resetOffset: TimeInterval) -> [String: Any] {
        [
            "usedPercent": used,
            "windowDurationMins": minutes,
            "resetsAt": now.addingTimeInterval(resetOffset).timeIntervalSince1970
        ]
    }

    private func resetCreditPayload(availableCount: Int, credits: Any) -> [String: Any] {
        [
            "rateLimits": ["primary": window(used: 18, minutes: 10_080, resetOffset: 500_000)],
            "rateLimitResetCredits": [
                "availableCount": availableCount,
                "credits": credits
            ]
        ]
    }
}
