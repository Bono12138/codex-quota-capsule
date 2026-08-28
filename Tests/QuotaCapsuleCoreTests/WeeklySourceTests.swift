@testable import QuotaCapsuleCore
import Foundation
import Testing

@Suite("Weekly source parsing")
struct WeeklySourceTests {
    private let now = Date(timeIntervalSince1970: 1_789_000_000)

    @Test("the source snapshot supports a weekly reading")
    func sourceSnapshotSupportsWeeklyReading() {
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

    @Test("five-hour and weekly candidates are selected by duration")
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
        #expect(snapshot.fiveHourWindow?.usedPercent == 41)
        #expect(snapshot.fiveHourWindow?.windowMinutes == 300)
        #expect(snapshot.weeklyWindow?.usedPercent == 18)
        #expect(snapshot.weeklyWindow?.windowMinutes == 10_080)
    }

    @Test("a payload with only a valid five-hour window is usable")
    func parserAcceptsPayloadWithOnlyFiveHourWindow() {
        let snapshot = CodexRateLimitParser.parse(
            result: [
                "rateLimits": [
                    "primary": window(used: 10, minutes: 300, resetOffset: 3_600)
                ]
            ],
            fetchedAt: now
        )

        #expect(snapshot.sourceStatus == .ok)
        #expect(snapshot.fiveHourWindow?.usedPercent == 10)
        #expect(snapshot.weeklyWindow == nil)
    }

    @Test("an arbitrary short window is not treated as five-hour")
    func parserRejectsNonFiveHourShortWindow() {
        let snapshot = CodexRateLimitParser.parse(
            result: ["rateLimits": ["primary": window(used: 10, minutes: 15, resetOffset: 600)]],
            fetchedAt: now
        )

        #expect(snapshot.sourceStatus == .error)
        #expect(snapshot.fiveHourWindow == nil)
    }

    @Test("the generic Codex bucket wins and Spark limits stay separate")
    func parserKeepsLimitBucketsSeparate() {
        let snapshot = CodexRateLimitParser.parse(
            result: [
                "rateLimits": ["primary": window(used: 99, minutes: 300, resetOffset: 3_600)],
                "rateLimitsByLimitId": [
                    "codex": ["primary": window(used: 2, minutes: 10_080, resetOffset: 500_000)],
                    "codex_bengalfox": [
                        "primary": window(used: 77, minutes: 300, resetOffset: 3_600),
                        "secondary": window(used: 44, minutes: 10_080, resetOffset: 500_000)
                    ]
                ]
            ],
            fetchedAt: now
        )

        #expect(snapshot.sourceStatus == .ok)
        #expect(snapshot.weeklyWindow?.usedPercent == 2)
        #expect(snapshot.fiveHourWindow == nil)
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
        #expect(reduced.snapshot.fiveHourWindow == current.fiveHourWindow)
        #expect(reduced.snapshot.resetCreditBank == bank)
        #expect(reduced.latestAttemptSnapshot.resetCreditBank == nil)
    }

    @Test("a five-hour-only success is adopted without entering weekly confirmation")
    func fiveHourOnlySuccessDoesNotLookLikeWeeklyConfirmation() {
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
            errorMessage: nil
        )
        let currentForecast = WeeklyRunwayPredictor.predict(
            snapshot: current,
            quality: WeeklyQualityEngine.analyze([], now: now),
            now: now
        )
        let fiveHourOnly = AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .ok,
            fetchedAt: now.addingTimeInterval(60),
            fiveHourWindow: QuotaWindow(
                label: "five_hour",
                windowMinutes: 300,
                usedPercent: 23,
                remainingPercent: 77,
                resetsAt: now.addingTimeInterval(10_000)
            ),
            weeklyWindow: nil,
            errorMessage: nil
        )

        let result = QuotaRefreshReducer.reduceForecastResult(
            currentForecast: currentForecast,
            newSnapshot: fiveHourOnly,
            weeklyReadings: [],
            now: fiveHourOnly.fetchedAt
        )

        #expect(result.shouldAdoptLiveSnapshot)
        #expect(result.forecast.state == .unavailable)
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
