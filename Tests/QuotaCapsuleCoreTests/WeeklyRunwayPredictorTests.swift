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

    @Test("the sustainable rate uses the full remaining allowance without a hidden reserve")
    func sustainableRateUsesFullRemainingAllowance() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 65, daysRemaining: 4),
            quality: quality(values: [25, 30, 35], spacingHours: 12),
            now: now
        )

        #expect(forecast.sustainableRatePerDay == 16.25)
        #expect(forecast.next24HourBudget == 16.25)
    }

    @Test("the last-24-hour metric is actual consumption rather than a daily rate")
    func last24HoursReportsObservedConsumption() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 70, daysRemaining: 4),
            quality: quality(values: [20, 25, 30], spacingHours: 24),
            now: now
        )

        #expect(forecast.last24HourUsageBand == PercentageBand(lower: 4, upper: 6))
        #expect(forecast.currentCycleTrend.count == 3)
        #expect(forecast.currentCycleTrend.last?.usedPercent == 30)
    }

    @Test("the observed usage summary uses the actual clean-segment endpoints")
    func observedUsageUsesActualCoverage() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 65, daysRemaining: 4),
            quality: quality(values: [25, 30, 35], spacingHours: 24),
            now: now
        )

        #expect(forecast.observedUsage == ObservedUsageSummary(
            coverageSeconds: 48 * 3_600,
            increaseBand: PercentageBand(lower: 9, upper: 11)
        ))
    }

    @Test("flat integer readings do not claim a zero pace")
    func flatIntegerReadingsDoNotClaimZeroPace() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 99, daysRemaining: 6),
            quality: quality(values: [1, 1, 1, 1, 1], spacingHours: 2, resetDays: 6),
            now: now
        )

        #expect(forecast.state == .earlyEstimate)
        #expect(forecast.cycleRateBandPerDay != nil)
        #expect(forecast.paceEvidence.map(\.kind) == [.cycle])
        #expect(forecast.confidence == .low)
    }

    @Test("a zero reading just after reset reports no observed consumption")
    func zeroReadingAfterResetDoesNotWarn() {
        let daysRemaining = 7 - 10.0 / 1_440
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 100, daysRemaining: daysRemaining),
            quality: quality(values: [0], spacingHours: 1, resetDays: daysRemaining),
            now: now
        )
        let model = CapsuleDisplayModel.make(forecast: forecast, locale: .zhHans)

        #expect(forecast.state == .earlyEstimate)
        #expect(forecast.paceEvidence.isEmpty)
        #expect(forecast.projectedRemainingBandAtReset == nil)
        #expect(forecast.confidenceReason == "no-consumption-observed")
        #expect(model.defaultText == "尚未观察到消耗；可先按未来 24 小时建议使用")
        #expect(!model.defaultText.contains("偏快"))
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
        #expect(forecast.estimatedEmptyAtRange?.earliest ?? .distantFuture < forecast.estimatedEmptyAtRange?.latest ?? .distantPast)
        #expect(forecast.estimatedEmptyAtRange?.latest ?? .distantFuture < now.addingTimeInterval(3 * 86_400))
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

    @Test("a conservative projection above zero is enough")
    func conservativeProjectionAboveZeroIsEnough() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 65, daysRemaining: 4),
            quality: quality(values: [25, 35], spacingHours: 24),
            now: now
        )

        #expect(forecast.state == .enough)
        #expect(forecast.projectedRemainingBandAtReset?.lower ?? 0 > 0)
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

    @Test("history that disagrees with the live reading falls back to current-cycle evidence")
    func mismatchedHistoryFallsBackToEarlyEstimate() {
        let forecast = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 40, daysRemaining: 4),
            quality: quality(values: [20, 30], spacingHours: 24),
            now: now
        )

        #expect(forecast.state == .earlyEstimate)
        #expect(forecast.projectedRemainingBandAtReset != nil)
        #expect(forecast.paceEvidence.map(\.kind) == [.cycle])
        #expect(forecast.confidence == .low)
    }

    @Test("a failed refresh freezes the previous weekly forecast")
    func failedRefreshFreezesForecast() {
        let previous = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 65, daysRemaining: 4),
            quality: quality(values: [25, 35], spacingHours: 24),
            now: now
        )
        let failure = AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .error,
            fetchedAt: now.addingTimeInterval(60),
            weeklyWindow: nil,
            errorMessage: "network unavailable"
        )

        let result = QuotaRefreshReducer.reduceForecast(
            currentForecast: previous,
            newSnapshot: failure,
            weeklyReadings: [],
            now: now.addingTimeInterval(60)
        )

        #expect(result == previous)
    }

    @Test("a successful refresh recalculates from cleaned weekly history")
    func successfulRefreshRecalculatesForecast() {
        let live = snapshot(remaining: 65, daysRemaining: 4)
        let history = [25.0, 30.0, 35.0].enumerated().map { index, used in
            WeeklyQuotaReading(
                provider: "codex",
                sourceStatus: .ok,
                fetchedAt: now.addingTimeInterval(Double(index - 2) * 12 * 3_600),
                windowMinutes: 10_080,
                usedPercent: used,
                remainingPercent: 100 - used,
                resetsAt: now.addingTimeInterval(4 * 86_400),
                errorMessage: nil
            )
        }
        let previous = WeeklyRunwayPredictor.predict(
            snapshot: snapshot(remaining: 99, daysRemaining: 6),
            quality: quality(values: [1], spacingHours: 1, resetDays: 6),
            now: now
        )

        let result = QuotaRefreshReducer.reduceForecast(
            currentForecast: previous,
            newSnapshot: live,
            weeklyReadings: history,
            now: now
        )

        #expect(result.state == .enough)
        #expect(result != previous)
    }

    @Test("an unconfirmed reset candidate exposes calibration with accepted data")
    func resetCandidateExposesCalibrationWithAcceptedData() {
        let previousSnapshot = snapshot(remaining: 70, daysRemaining: 4)
        let previous = WeeklyRunwayPredictor.predict(
            snapshot: previousSnapshot,
            quality: quality(values: [20, 25, 30], spacingHours: 12),
            now: now
        )
        let candidateReset = now.addingTimeInterval(6 * 86_400)
        let candidateSnapshot = AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .ok,
            fetchedAt: now,
            weeklyWindow: QuotaWindow(
                label: "weekly",
                windowMinutes: 10_080,
                usedPercent: 2,
                remainingPercent: 98,
                resetsAt: candidateReset
            ),
            errorMessage: nil
        )
        let history = [
            WeeklyQuotaReading(
                provider: "codex",
                sourceStatus: .ok,
                fetchedAt: now.addingTimeInterval(-60),
                windowMinutes: 10_080,
                usedPercent: 30,
                remainingPercent: 70,
                resetsAt: now.addingTimeInterval(4 * 86_400),
                errorMessage: nil
            ),
            WeeklyQuotaReading(
                provider: "codex",
                sourceStatus: .ok,
                fetchedAt: now,
                windowMinutes: 10_080,
                usedPercent: 2,
                remainingPercent: 98,
                resetsAt: candidateReset,
                errorMessage: nil
            )
        ]

        let reduction = QuotaRefreshReducer.reduceForecastResult(
            currentForecast: previous,
            newSnapshot: candidateSnapshot,
            weeklyReadings: history,
            now: now
        )

        #expect(WeeklyQualityEngine.analyze(history, now: now).state == .calibrating)
        #expect(reduction.forecast.state == .calibrating)
        #expect(reduction.forecast.usedPercent == 30)
        #expect(reduction.forecast.remainingPercent == 70)
        #expect(reduction.forecast.projectedRemainingBandAtReset == nil)
        #expect(reduction.forecast.paceEvidence.isEmpty)
        #expect(!reduction.shouldAdoptLiveSnapshot)
    }
}
