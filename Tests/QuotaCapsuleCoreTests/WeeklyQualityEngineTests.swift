@testable import QuotaCapsuleCore
import Foundation
import Testing

@Suite("Weekly data quality")
struct WeeklyQualityEngineTests {
    private let origin = Date(timeIntervalSince1970: 2_000_000_000)

    private func reading(
        minute: Int,
        used: Double,
        resetOffset: TimeInterval = 500_000,
        sourceStatus: SourceStatus = .ok
    ) -> WeeklyQuotaReading {
        let fetchedAt = origin.addingTimeInterval(TimeInterval(minute * 60))
        return WeeklyQuotaReading(
            provider: "codex",
            sourceStatus: sourceStatus,
            fetchedAt: fetchedAt,
            windowMinutes: 10_080,
            usedPercent: used,
            remainingPercent: 100 - used,
            resetsAt: origin.addingTimeInterval(resetOffset),
            errorMessage: nil
        )
    }

    @Test("second-level reset jitter remains one stable cycle")
    func secondLevelResetJitterStaysInOneCycle() {
        let readings = [
            reading(minute: 0, used: 10, resetOffset: 500_000),
            reading(minute: 1, used: 10, resetOffset: 500_002),
            reading(minute: 2, used: 11, resetOffset: 500_004)
        ]

        let result = WeeklyQualityEngine.analyze(readings, now: origin.addingTimeInterval(130))

        #expect(result.state == .stable)
        #expect(Set(result.observations.map(\.cycleID)).count == 1)
        #expect(Set(result.observations.map(\.canonicalResetAt)).count == 1)
        #expect(result.flags.contains(.resetJitter))
    }

    @Test("alternating one and five percent streams are quarantined")
    func alternatingOneAndFivePercentCalibrates() {
        let readings = [
            reading(minute: 0, used: 1, resetOffset: 500_000),
            reading(minute: 1, used: 5, resetOffset: 500_070),
            reading(minute: 2, used: 1, resetOffset: 500_000),
            reading(minute: 3, used: 5, resetOffset: 500_070),
            reading(minute: 4, used: 1, resetOffset: 500_000)
        ]

        let result = WeeklyQualityEngine.analyze(readings, now: origin.addingTimeInterval(250))

        #expect(result.state == .unstable)
        #expect(result.flags.contains(.alternatingStream))
        #expect(result.observations.count < readings.count)
    }

    @Test("stale data never produces a stable forecast input")
    func staleLatestReadingIsStale() {
        let result = WeeklyQualityEngine.analyze(
            [reading(minute: 0, used: 10)],
            now: origin.addingTimeInterval(181)
        )

        #expect(result.state == .stale)
        #expect(result.flags.contains(.staleSource))
        #expect(result.observations.map(\.usedPercent) == [10])
    }

    @Test("a materially future-dated reading is unavailable")
    func futureDatedReadingIsRejected() {
        let future = reading(minute: 10, used: 10)

        let result = WeeklyQualityEngine.analyze([future], now: origin)

        #expect(result.state == .unavailable)
        #expect(result.observations.isEmpty)
    }

    @Test("flat polling is reduced to one representative per five-minute bucket")
    func flatPollingDoesNotDominateHistory() {
        let readings = (0..<16).map { reading(minute: $0, used: 10) }

        let result = WeeklyQualityEngine.analyze(readings, now: origin.addingTimeInterval(15 * 60 + 10))

        #expect(result.state == .stable)
        #expect(result.observations.count == 4)
    }

    @Test("one lower reading is quarantined instead of rewriting history")
    func oneLowerReadingDoesNotChangeAcceptedSegment() {
        let readings = [
            reading(minute: 0, used: 10),
            reading(minute: 1, used: 11),
            reading(minute: 2, used: 9)
        ]

        let result = WeeklyQualityEngine.analyze(readings, now: origin.addingTimeInterval(130))

        #expect(result.state == .calibrating)
        #expect(result.observations.map(\.usedPercent) == [10, 11])
        #expect(result.flags.contains(.correction))
    }

    @Test("three consistent lower readings rebase into a new segment")
    func threeLowerReadingsConfirmCorrection() {
        let readings = [
            reading(minute: 0, used: 10),
            reading(minute: 1, used: 11),
            reading(minute: 2, used: 8),
            reading(minute: 3, used: 8),
            reading(minute: 4, used: 9)
        ]

        let result = WeeklyQualityEngine.analyze(readings, now: origin.addingTimeInterval(250))

        #expect(result.state == .stable)
        #expect(result.observations.suffix(3).map(\.usedPercent) == [8, 8, 9])
        #expect(Set(result.observations.suffix(3).map(\.segmentID)).count == 1)
        #expect(result.observations.last?.segmentID != result.observations.first?.segmentID)
        #expect(result.flags.contains(.correction))
    }

    @Test("a later reset and usage drop require three readings over two minutes")
    func threeReadingsConfirmNewCycle() {
        let readings = [
            reading(minute: 0, used: 75, resetOffset: 100_000),
            reading(minute: 1, used: 75, resetOffset: 100_001),
            reading(minute: 2, used: 1, resetOffset: 650_000),
            reading(minute: 3, used: 1, resetOffset: 650_001),
            reading(minute: 4, used: 2, resetOffset: 649_999)
        ]

        let result = WeeklyQualityEngine.analyze(readings, now: origin.addingTimeInterval(250))

        #expect(result.state == .stable)
        #expect(Set(result.observations.map(\.cycleID)).count == 2)
        #expect(result.observations.last?.cycleID != result.observations.first?.cycleID)
        #expect(result.flags.contains(.resetCandidate))
    }

    @Test("a new-cycle candidate remains calibrating before confirmation")
    func unconfirmedNewCycleCalibrates() {
        let readings = [
            reading(minute: 0, used: 75, resetOffset: 100_000),
            reading(minute: 1, used: 1, resetOffset: 650_000),
            reading(minute: 2, used: 1, resetOffset: 650_001)
        ]

        let result = WeeklyQualityEngine.analyze(readings, now: origin.addingTimeInterval(130))

        #expect(result.state == .calibrating)
        #expect(result.observations.map(\.usedPercent) == [75])
        #expect(result.flags.contains(.resetCandidate))
    }
}
