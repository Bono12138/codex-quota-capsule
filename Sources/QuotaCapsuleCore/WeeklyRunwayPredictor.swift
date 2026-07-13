import Foundation

public struct PaceBand: Equatable, Sendable {
    public let lower: Double
    public let upper: Double

    public init(lower: Double, upper: Double) {
        self.lower = lower
        self.upper = upper
    }
}

public struct PercentageBand: Equatable, Sendable {
    public let lower: Double
    public let upper: Double

    public init(lower: Double, upper: Double) {
        self.lower = lower
        self.upper = upper
    }
}

public struct ExhaustionDateRange: Equatable, Sendable {
    public let earliest: Date
    public let latest: Date?

    public init(earliest: Date, latest: Date?) {
        self.earliest = earliest
        self.latest = latest
    }
}

public enum WeeklyRunwayState: String, Codable, Equatable, Sendable {
    case unavailable
    case exhausted
    case calibrating
    case enough
    case watch
    case mayRunOut
}

public enum ForecastConfidence: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}

public struct WeeklyRunwayForecast: Equatable, Sendable {
    public let state: WeeklyRunwayState
    public let confidence: ForecastConfidence
    public let usedPercent: Double?
    public let remainingPercent: Double?
    public let elapsedPercent: Double?
    public let daysUntilReset: Double?
    public let sustainableRatePerDay: Double?
    public let recentRateBandPerDay: PaceBand?
    public let cycleRateBandPerDay: PaceBand?
    public let projectedRemainingBandAtReset: PercentageBand?
    public let estimatedEmptyAtRange: ExhaustionDateRange?
    public let next24HourBudget: Double?
    public let headline: String
    public let detail: String
    public let qualityExplanation: String

    public init(
        state: WeeklyRunwayState,
        confidence: ForecastConfidence,
        usedPercent: Double?,
        remainingPercent: Double?,
        elapsedPercent: Double?,
        daysUntilReset: Double?,
        sustainableRatePerDay: Double?,
        recentRateBandPerDay: PaceBand?,
        cycleRateBandPerDay: PaceBand?,
        projectedRemainingBandAtReset: PercentageBand?,
        estimatedEmptyAtRange: ExhaustionDateRange?,
        next24HourBudget: Double?,
        headline: String = "",
        detail: String = "",
        qualityExplanation: String = ""
    ) {
        self.state = state
        self.confidence = confidence
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.elapsedPercent = elapsedPercent
        self.daysUntilReset = daysUntilReset
        self.sustainableRatePerDay = sustainableRatePerDay
        self.recentRateBandPerDay = recentRateBandPerDay
        self.cycleRateBandPerDay = cycleRateBandPerDay
        self.projectedRemainingBandAtReset = projectedRemainingBandAtReset
        self.estimatedEmptyAtRange = estimatedEmptyAtRange
        self.next24HourBudget = next24HourBudget
        self.headline = headline
        self.detail = detail
        self.qualityExplanation = qualityExplanation
    }
}

public enum WeeklyRunwayPredictor {
    public static let reservePercent = 5.0
    private static let minimumPairSeparation: TimeInterval = 30 * 60
    private static let minimumCoverage: TimeInterval = 6 * 60 * 60
    private static let recentHorizon: TimeInterval = 24 * 60 * 60

    public static func predict(
        snapshot: AgentQuotaSnapshot,
        quality: WeeklyQualityResult,
        now: Date = Date(),
        locale: QuotaLocale = .zhHans
    ) -> WeeklyRunwayForecast {
        guard snapshot.sourceStatus == .ok,
              let window = snapshot.weeklyWindow,
              isValid(window, now: now) else {
            return unavailable()
        }

        let daysRemaining = window.resetsAt.timeIntervalSince(now) / 86_400
        let elapsed = elapsedPercent(window: window, now: now)
        let sustainable = max(0, window.remainingPercent - reservePercent) / daysRemaining
        let budget = min(window.remainingPercent, sustainable)

        if window.remainingPercent <= 0 {
            return WeeklyRunwayForecast(
                state: .exhausted,
                confidence: .low,
                usedPercent: window.usedPercent,
                remainingPercent: 0,
                elapsedPercent: elapsed,
                daysUntilReset: daysRemaining,
                sustainableRatePerDay: 0,
                recentRateBandPerDay: nil,
                cycleRateBandPerDay: nil,
                projectedRemainingBandAtReset: PercentageBand(lower: 0, upper: 0),
                estimatedEmptyAtRange: ExhaustionDateRange(earliest: now, latest: now),
                next24HourBudget: 0
            )
        }

        guard quality.state != .stale, quality.state != .unavailable else {
            return unavailable(
                used: window.usedPercent,
                remaining: window.remainingPercent,
                elapsed: elapsed,
                daysRemaining: daysRemaining
            )
        }

        guard quality.state == .stable else {
            return calibrating(
                window: window,
                elapsed: elapsed,
                daysRemaining: daysRemaining,
                sustainable: sustainable,
                budget: budget
            )
        }

        let active = activeCycleAndSegment(quality.observations)
        guard let latestObservation = active.last,
              abs(latestObservation.usedPercent - window.usedPercent) <= 1.5,
              abs(latestObservation.canonicalResetAt.timeIntervalSince(window.resetsAt)) <= WeeklyQualityEngine.resetClusterTolerance else {
            return calibrating(
                window: window,
                elapsed: elapsed,
                daysRemaining: daysRemaining,
                sustainable: sustainable,
                budget: budget
            )
        }
        let cycleBand = qualifiedPaceBand(active)
        let recentObservations = active.filter { now.timeIntervalSince($0.fetchedAt) <= recentHorizon }
        let recentBand = qualifiedPaceBand(recentObservations)

        guard let cycleBand, let recentBand else {
            return calibrating(
                window: window,
                elapsed: elapsed,
                daysRemaining: daysRemaining,
                sustainable: sustainable,
                budget: budget,
                cycleBand: cycleBand
            )
        }

        let pace = PaceBand(
            lower: min(cycleBand.lower, recentBand.lower),
            upper: max(cycleBand.upper, recentBand.upper)
        )
        let projected = PercentageBand(
            lower: window.remainingPercent - pace.upper * daysRemaining,
            upper: window.remainingPercent - pace.lower * daysRemaining
        )
        let exhaustion = exhaustionRange(
            remaining: window.remainingPercent,
            pace: pace,
            now: now
        )
        let confidence = forecastConfidence(active, recentBand: recentBand)
        let state: WeeklyRunwayState
        if projected.lower >= reservePercent {
            state = .enough
        } else if projected.upper < 0 {
            state = .mayRunOut
        } else {
            state = .watch
        }

        return WeeklyRunwayForecast(
            state: state,
            confidence: confidence,
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            elapsedPercent: elapsed,
            daysUntilReset: daysRemaining,
            sustainableRatePerDay: sustainable,
            recentRateBandPerDay: recentBand,
            cycleRateBandPerDay: cycleBand,
            projectedRemainingBandAtReset: projected,
            estimatedEmptyAtRange: exhaustion,
            next24HourBudget: budget
        )
    }

    private static func isValid(_ window: QuotaWindow, now: Date) -> Bool {
        abs(window.windowMinutes - 10_080) <= 60
            && window.usedPercent.isFinite
            && window.remainingPercent.isFinite
            && (0...100).contains(window.usedPercent)
            && (0...100).contains(window.remainingPercent)
            && abs(window.usedPercent + window.remainingPercent - 100) <= 1.5
            && window.resetsAt > now
    }

    private static func elapsedPercent(window: QuotaWindow, now: Date) -> Double {
        let start = window.resetsAt.addingTimeInterval(-Double(window.windowMinutes) * 60)
        let elapsed = now.timeIntervalSince(start) / (Double(window.windowMinutes) * 60) * 100
        return min(100, max(0, elapsed))
    }

    private static func activeCycleAndSegment(_ observations: [WeeklyObservation]) -> [WeeklyObservation] {
        guard let last = observations.last else { return [] }
        return observations.filter { $0.cycleID == last.cycleID && $0.segmentID == last.segmentID }
    }

    private static func qualifiedPaceBand(_ observations: [WeeklyObservation]) -> PaceBand? {
        guard let first = observations.first,
              let last = observations.last,
              last.fetchedAt.timeIntervalSince(first.fetchedAt) >= minimumCoverage,
              upwardTransitionCount(observations) > 0 else {
            return nil
        }
        return robustPaceBand(observations)
    }

    private static func robustPaceBand(_ observations: [WeeklyObservation]) -> PaceBand? {
        struct Candidate {
            let lower: Double
            let upper: Double
            var midpoint: Double { (lower + upper) / 2 }
        }

        var candidates: [Candidate] = []
        for earlierIndex in observations.indices {
            for laterIndex in observations.indices where laterIndex > earlierIndex {
                let earlier = observations[earlierIndex]
                let later = observations[laterIndex]
                let duration = later.fetchedAt.timeIntervalSince(earlier.fetchedAt)
                guard duration >= minimumPairSeparation else { continue }
                let first = quantizedInterval(earlier.usedPercent)
                let second = quantizedInterval(later.usedPercent)
                let scale = 86_400 / duration
                candidates.append(Candidate(
                    lower: max(0, second.lower - first.upper) * scale,
                    upper: max(0, second.upper - first.lower) * scale
                ))
            }
        }
        guard !candidates.isEmpty else { return nil }

        if candidates.count >= 5 {
            let center = median(candidates.map(\.midpoint))
            let mad = median(candidates.map { abs($0.midpoint - center) })
            let tolerance = max(0.01, 3 * mad)
            candidates = candidates.filter { abs($0.midpoint - center) <= tolerance }
        }
        guard !candidates.isEmpty else { return nil }
        return PaceBand(
            lower: median(candidates.map(\.lower)),
            upper: median(candidates.map(\.upper))
        )
    }

    private static func quantizedInterval(_ value: Double) -> PercentageBand {
        let roundedInteger = value.rounded()
        if abs(value - roundedInteger) < 0.000_001 {
            return PercentageBand(lower: value, upper: min(100, value + 1))
        }

        let resolution: Double
        if abs(value * 10 - (value * 10).rounded()) < 0.000_001 {
            resolution = 0.1
        } else if abs(value * 100 - (value * 100).rounded()) < 0.000_001 {
            resolution = 0.01
        } else {
            resolution = 0.001
        }
        return PercentageBand(
            lower: max(0, value - resolution / 2),
            upper: min(100, value + resolution / 2)
        )
    }

    private static func upwardTransitionCount(_ observations: [WeeklyObservation]) -> Int {
        zip(observations, observations.dropFirst()).reduce(into: 0) { count, pair in
            if pair.1.usedPercent > pair.0.usedPercent {
                count += 1
            }
        }
    }

    private static func forecastConfidence(
        _ observations: [WeeklyObservation],
        recentBand: PaceBand
    ) -> ForecastConfidence {
        guard let first = observations.first, let last = observations.last else { return .low }
        let coverage = last.fetchedAt.timeIntervalSince(first.fetchedAt)
        if coverage >= recentHorizon && upwardTransitionCount(observations) >= 3 {
            return .high
        }
        return .medium
    }

    private static func exhaustionRange(
        remaining: Double,
        pace: PaceBand,
        now: Date
    ) -> ExhaustionDateRange? {
        guard pace.upper > 0 else { return nil }
        let earliest = now.addingTimeInterval(remaining / pace.upper * 86_400)
        let latest = pace.lower > 0
            ? now.addingTimeInterval(remaining / pace.lower * 86_400)
            : nil
        return ExhaustionDateRange(earliest: earliest, latest: latest)
    }

    private static func calibrating(
        window: QuotaWindow,
        elapsed: Double,
        daysRemaining: Double,
        sustainable: Double,
        budget: Double,
        cycleBand: PaceBand? = nil
    ) -> WeeklyRunwayForecast {
        WeeklyRunwayForecast(
            state: .calibrating,
            confidence: .low,
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            elapsedPercent: elapsed,
            daysUntilReset: daysRemaining,
            sustainableRatePerDay: sustainable,
            recentRateBandPerDay: nil,
            cycleRateBandPerDay: cycleBand,
            projectedRemainingBandAtReset: nil,
            estimatedEmptyAtRange: nil,
            next24HourBudget: budget
        )
    }

    private static func unavailable(
        used: Double? = nil,
        remaining: Double? = nil,
        elapsed: Double? = nil,
        daysRemaining: Double? = nil
    ) -> WeeklyRunwayForecast {
        WeeklyRunwayForecast(
            state: .unavailable,
            confidence: .low,
            usedPercent: used,
            remainingPercent: remaining,
            elapsedPercent: elapsed,
            daysUntilReset: daysRemaining,
            sustainableRatePerDay: nil,
            recentRateBandPerDay: nil,
            cycleRateBandPerDay: nil,
            projectedRemainingBandAtReset: nil,
            estimatedEmptyAtRange: nil,
            next24HourBudget: nil
        )
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
