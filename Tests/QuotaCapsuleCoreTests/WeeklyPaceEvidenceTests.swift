@testable import QuotaCapsuleCore
import Foundation
import Testing

@Suite("Adaptive weekly pace evidence")
struct WeeklyPaceEvidenceTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("the first valid reading produces bounded cycle evidence")
    func firstReadingProducesCycleEvidence() throws {
        let evidence = try #require(WeeklyPaceEvidence.cycle(
            window: window(used: 9, resetDays: 6.75),
            now: now
        ))

        #expect(evidence.kind == .cycle)
        #expect(abs(evidence.bandPerDay.lower - 34) < 0.000_001)
        #expect(abs(evidence.bandPerDay.upper - 38) < 0.000_001)
        #expect(evidence.reliability >= 0.1 && evidence.reliability < 0.55)
        #expect(abs(evidence.coverageHours - 6) < 0.000_001)
        #expect(evidence.transitionCount == 0)
    }

    @Test("zero use preserves uncertainty instead of claiming zero pace")
    func zeroUsePreservesUpperBound() throws {
        let evidence = try #require(WeeklyPaceEvidence.cycle(
            window: window(used: 0, resetDays: 6.75),
            now: now
        ))

        #expect(evidence.bandPerDay.lower == 0)
        #expect(evidence.bandPerDay.upper == 2)
    }

    @Test("a future cycle start is rejected")
    func futureCycleStartIsRejected() {
        #expect(WeeklyPaceEvidence.cycle(window: window(used: 9, resetDays: 8), now: now) == nil)
    }

    @Test("one transition in three hours is recent evidence")
    func shortTransitionIsActionable() throws {
        let evidence = try #require(WeeklyPaceEvidence.recent(
            observations: observations(values: [8, 9], spacingHours: 3),
            now: now
        ))

        #expect(evidence.kind == .recent)
        #expect(evidence.transitionCount == 1)
        #expect(abs(evidence.coverageHours - 3) < 0.000_001)
        #expect(evidence.bandPerDay.lower == 0)
        #expect(evidence.bandPerDay.upper == 16)
    }

    @Test("flat samples alone do not create recent pace certainty")
    func flatSamplesDoNotCreateRecentEvidence() {
        #expect(WeeklyPaceEvidence.recent(
            observations: observations(values: [9, 9, 9], spacingHours: 2),
            now: now
        ) == nil)
    }

    @Test("activity pace decays after a burst becomes idle")
    func burstPaceDecaysDuringIdle() throws {
        let burstEnd = now.addingTimeInterval(-12 * 3_600)
        let samples = [
            observation(at: burstEnd.addingTimeInterval(-2 * 3_600), used: 5),
            observation(at: burstEnd, used: 9)
        ]
        let immediate = try #require(WeeklyPaceEvidence.activity(observations: samples, now: burstEnd))
        let afterIdle = try #require(WeeklyPaceEvidence.activity(observations: samples, now: now))

        #expect(afterIdle.bandPerDay.upper < immediate.bandPerDay.upper)
        #expect(afterIdle.bandPerDay.lower < immediate.bandPerDay.lower)
        #expect(afterIdle.reliability < immediate.reliability)
    }

    @Test("activity pace propagates uncertainty from both quantized endpoints")
    func activityPacePropagatesEndpointUncertainty() throws {
        let samples = [
            observation(at: now.addingTimeInterval(-2 * 3_600), used: 5),
            observation(at: now, used: 9)
        ]
        let evidence = try #require(WeeklyPaceEvidence.activity(observations: samples, now: now))

        #expect(abs(evidence.bandPerDay.lower - 36) < 0.000_001)
        #expect(abs(evidence.bandPerDay.upper - 60) < 0.000_001)
    }

    @Test("activity segmentation distinguishes bursts, ordinary use, and idle gaps")
    func activitySegmentationClassifiesObservedTime() throws {
        let samples = [
            observation(at: now.addingTimeInterval(-30 * 3_600), used: 5),
            observation(at: now.addingTimeInterval(-29 * 3_600), used: 6),
            observation(at: now.addingTimeInterval(-28 * 3_600), used: 7),
            observation(at: now.addingTimeInterval(-16 * 3_600), used: 8),
            observation(at: now.addingTimeInterval(-4 * 3_600), used: 8)
        ]
        let summary = try #require(WeeklyPaceEvidence.activitySegments(observations: samples, now: now))

        #expect(abs(summary.activeBurstHours - 2) < 0.000_001)
        #expect(abs(summary.ordinaryUseHours - 12) < 0.000_001)
        #expect(abs(summary.idleHours - 16) < 0.000_001)
        #expect(abs(summary.dutyRatio - (14.0 / 30.0)) < 0.000_001)
        #expect(summary.transitionCount == 3)
    }

    @Test("downward corrections never count as consumption")
    func correctionsDoNotCountAsConsumption() {
        let samples = observations(values: [9, 8], spacingHours: 3)
        #expect(WeeklyPaceEvidence.countUpwardTransitions(samples) == 0)
        #expect(WeeklyPaceEvidence.activity(observations: samples, now: now) == nil)
    }

    @Test("a well-observed completed cycle becomes a weak historical prior")
    func completedCycleProducesHistoricalPrior() throws {
        let previous = [10.0, 20, 30, 40].enumerated().map { index, value in
            observation(
                at: now.addingTimeInterval(Double(index - 4) * 24 * 3_600),
                used: value,
                cycleID: 0
            )
        }
        let current = observation(at: now, used: 2, cycleID: 1)
        let evidence = try #require(WeeklyPaceEvidence.historical(
            observations: previous + [current],
            currentCycleID: 1
        ))

        #expect(evidence.kind == .historical)
        #expect(abs(evidence.bandPerDay.lower - (29.0 / 3.0)) < 0.000_001)
        #expect(abs(evidence.bandPerDay.upper - (31.0 / 3.0)) < 0.000_001)
        #expect(evidence.reliability <= 0.35)
        #expect(evidence.transitionCount == 3)
    }

    @Test("a short fragment is not treated as a historical cycle")
    func incompleteCycleIsNotHistoricalPrior() {
        let previous = [10.0, 20].enumerated().map { index, value in
            observation(at: now.addingTimeInterval(Double(index - 2) * 6 * 3_600), used: value, cycleID: 0)
        }
        #expect(WeeklyPaceEvidence.historical(
            observations: previous + [observation(at: now, used: 2, cycleID: 1)],
            currentCycleID: 1
        ) == nil)
    }

    private func window(used: Double, resetDays: Double) -> QuotaWindow {
        QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: used,
            remainingPercent: 100 - used,
            resetsAt: now.addingTimeInterval(resetDays * 86_400)
        )
    }

    private func observations(values: [Double], spacingHours: Double) -> [WeeklyObservation] {
        let start = now.addingTimeInterval(-Double(max(0, values.count - 1)) * spacingHours * 3_600)
        return values.enumerated().map { index, value in
            observation(at: start.addingTimeInterval(Double(index) * spacingHours * 3_600), used: value)
        }
    }

    private func observation(at: Date, used: Double, cycleID: Int = 0) -> WeeklyObservation {
        WeeklyObservation(
            fetchedAt: at,
            canonicalResetAt: now.addingTimeInterval(6 * 86_400),
            usedPercent: used,
            remainingPercent: 100 - used,
            cycleID: cycleID,
            segmentID: 0
        )
    }
}
