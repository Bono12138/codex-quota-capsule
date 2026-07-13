@testable import QuotaCapsuleCore
import Foundation
import Testing

@Suite("Weekly runway forecasting")
struct WeeklyRunwayPredictorTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func snapshot(remaining: Double, daysRemaining: Double) -> AgentQuotaSnapshot {
        AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .ok,
            fetchedAt: now,
            weeklyWindow: QuotaWindow(
                label: "weekly",
                windowMinutes: 10_080,
                usedPercent: 100 - remaining,
                remainingPercent: remaining,
                resetsAt: now.addingTimeInterval(daysRemaining * 86_400)
            ),
            errorMessage: nil
        )
    }

    private func quality(
        values: [Double],
        spacingHours: Double,
        resetDays: Double = 4,
        state: WeeklyQualityState = .stable
    ) -> WeeklyQualityResult {
        let start = now.addingTimeInterval(-Double(max(0, values.count - 1)) * spacingHours * 3_600)
        let observations = values.enumerated().map { index, value in
            WeeklyObservation(
                fetchedAt: start.addingTimeInterval(Double(index) * spacingHours * 3_600),
                canonicalResetAt: now.addingTimeInterval(resetDays * 86_400),
                usedPercent: value,
                remainingPercent: 100 - value,
                cycleID: 0,
                segmentID: 0
            )
        }
        return WeeklyQualityResult(
            state: state,
            observations: observations,
            canonicalResetAt: now.addingTimeInterval(resetDays * 86_400),
            flags: []
        )
    }

    @Test("the sustainable rate preserves a five-point reset reserve")
    func sustainableRateLeavesFivePercentReserve() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 65, daysRemaining: 4),
            quality: quality(values: [25, 30, 35], spacingHours: 12),
            now: now
        )

        #expect(forecast.sustainableRatePerDay == 15)
        #expect(forecast.next24HourBudget == 15)
    }

    @Test("flat integer readings do not claim a zero pace")
    func flatIntegerReadingsDoNotClaimZeroPace() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 99, daysRemaining: 6),
            quality: quality(values: [1, 1, 1, 1, 1], spacingHours: 2, resetDays: 6),
            now: now
        )

        #expect(forecast.state == .calibrating)
        #expect(forecast.recentRateBandPerDay == nil)
        #expect(forecast.confidence == .low)
    }

    @Test("both pace scenarios running out produces may-run-out")
    func bothPaceScenariosRunningOutIsMayRunOut() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 20, daysRemaining: 3),
            quality: quality(values: [50, 65, 80], spacingHours: 24, resetDays: 3),
            now: now
        )

        #expect(forecast.state == .mayRunOut)
        #expect(forecast.projectedRemainingBandAtReset?.upper ?? 0 < 0)
    }

    @Test("a projection range crossing zero is watch, not may-run-out")
    func uncertaintyCrossingZeroIsWatch() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 30, daysRemaining: 3),
            quality: quality(values: [60, 65, 70], spacingHours: 12, resetDays: 3),
            now: now
        )

        #expect(forecast.state == .watch)
        #expect(forecast.projectedRemainingBandAtReset?.lower ?? 1 < 0)
        #expect(forecast.projectedRemainingBandAtReset?.upper ?? -1 >= 0)
    }

    @Test("a pessimistic reset reserve of five percent is enough")
    func pessimisticFivePercentReserveIsEnough() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 65, daysRemaining: 4),
            quality: quality(values: [25, 35], spacingHours: 24),
            now: now
        )

        #expect(forecast.state == .enough)
        #expect(forecast.projectedRemainingBandAtReset?.lower ?? 0 >= 5)
    }

    @Test("exhaustion takes precedence over low-confidence evidence")
    func exhaustedTakesPrecedenceOverCalibration() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 0, daysRemaining: 2),
            quality: quality(values: [100], spacingHours: 1, resetDays: 2, state: .unstable),
            now: now
        )

        #expect(forecast.state == .exhausted)
        #expect(forecast.next24HourBudget == 0)
    }

    @Test("stale quality never emits a runway judgment")
    func staleQualityIsUnavailable() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 70, daysRemaining: 4),
            quality: quality(values: [20, 30], spacingHours: 12, state: .stale),
            now: now
        )

        #expect(forecast.state == .unavailable)
        #expect(forecast.projectedRemainingBandAtReset == nil)
    }

    @Test("history that disagrees with the live reading cannot drive a forecast")
    func mismatchedHistoryCalibrates() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 40, daysRemaining: 4),
            quality: quality(values: [20, 30], spacingHours: 24),
            now: now
        )

        #expect(forecast.state == .calibrating)
        #expect(forecast.projectedRemainingBandAtReset == nil)
        #expect(forecast.confidence == .low)
    }
}
