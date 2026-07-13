import Foundation

public struct PaceBand: Equatable, Sendable {
    public let lower: Double
    public let upper: Double

    public init(lower: Double, upper: Double) {
        self.lower = lower
        self.upper = upper
    }
}

public enum PaceEvidenceKind: String, Codable, Equatable, Sendable {
    case cycle
    case recent
    case activity
    case historical
}

public struct PaceEvidence: Equatable, Sendable {
    public let kind: PaceEvidenceKind
    public let bandPerDay: PaceBand
    public let reliability: Double
    public let transitionCount: Int
    public let coverageHours: Double

    public init(
        kind: PaceEvidenceKind,
        bandPerDay: PaceBand,
        reliability: Double,
        transitionCount: Int,
        coverageHours: Double
    ) {
        self.kind = kind
        self.bandPerDay = bandPerDay
        self.reliability = reliability
        self.transitionCount = transitionCount
        self.coverageHours = coverageHours
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

public struct WeeklyTrendPoint: Equatable, Sendable {
    public let at: Date
    public let usedPercent: Double

    public init(at: Date, usedPercent: Double) {
        self.at = at
        self.usedPercent = usedPercent
    }
}

public enum WeeklyRunwayState: String, Codable, Equatable, Sendable {
    case unavailable
    case exhausted
    case calibrating
    case earlyEstimate
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
    public let last24HourUsageBand: PercentageBand?
    public let projectedRemainingBandAtReset: PercentageBand?
    public let estimatedEmptyAtRange: ExhaustionDateRange?
    public let next24HourBudget: Double?
    public let currentCycleTrend: [WeeklyTrendPoint]
    public let paceEvidence: [PaceEvidence]
    public let confidenceReason: String
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
        last24HourUsageBand: PercentageBand? = nil,
        projectedRemainingBandAtReset: PercentageBand?,
        estimatedEmptyAtRange: ExhaustionDateRange?,
        next24HourBudget: Double?,
        currentCycleTrend: [WeeklyTrendPoint] = [],
        paceEvidence: [PaceEvidence] = [],
        confidenceReason: String = "",
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
        self.last24HourUsageBand = last24HourUsageBand
        self.projectedRemainingBandAtReset = projectedRemainingBandAtReset
        self.estimatedEmptyAtRange = estimatedEmptyAtRange
        self.next24HourBudget = next24HourBudget
        self.currentCycleTrend = currentCycleTrend
        self.paceEvidence = paceEvidence
        self.confidenceReason = confidenceReason
        self.headline = headline
        self.detail = detail
        self.qualityExplanation = qualityExplanation
    }
}

public enum WeeklyRunwayPredictor {
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

        if quality.state == .calibrating {
            return calibratingFromAcceptedObservation(
                quality.observations,
                windowMinutes: window.windowMinutes,
                now: now
            )
        }

        let daysRemaining = window.resetsAt.timeIntervalSince(now) / 86_400
        let elapsed = elapsedPercent(window: window, now: now)
        let sustainable = window.remainingPercent / daysRemaining
        let budget = min(window.remainingPercent, sustainable * min(1, daysRemaining))
        let active = quality.state == .stable ? activeCycleAndSegment(quality.observations) : []
        let last24HourUsage = last24HourUsageBand(active, now: now)
        let trend = trendPoints(active)

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
                last24HourUsageBand: last24HourUsage,
                projectedRemainingBandAtReset: PercentageBand(lower: 0, upper: 0),
                estimatedEmptyAtRange: ExhaustionDateRange(earliest: now, latest: now),
                next24HourBudget: 0,
                currentCycleTrend: trend,
                confidenceReason: "exhausted"
            )
        }

        guard quality.state != .stale,
              quality.state != .unavailable,
              quality.state != .unstable else {
            return unavailable(
                used: window.usedPercent,
                remaining: window.remainingPercent,
                elapsed: elapsed,
                daysRemaining: daysRemaining
            )
        }

        if window.usedPercent == 0 {
            return WeeklyRunwayForecast(
                state: .earlyEstimate,
                confidence: .low,
                usedPercent: 0,
                remainingPercent: window.remainingPercent,
                elapsedPercent: elapsed,
                daysUntilReset: daysRemaining,
                sustainableRatePerDay: sustainable,
                recentRateBandPerDay: nil,
                cycleRateBandPerDay: nil,
                last24HourUsageBand: nil,
                projectedRemainingBandAtReset: nil,
                estimatedEmptyAtRange: nil,
                next24HourBudget: budget,
                currentCycleTrend: trend,
                paceEvidence: [],
                confidenceReason: "no-consumption-observed"
            )
        }

        guard let cycleEvidence = WeeklyPaceEvidence.cycle(window: window, now: now) else {
            return unavailable(
                used: window.usedPercent,
                remaining: window.remainingPercent,
                elapsed: elapsed,
                daysRemaining: daysRemaining
            )
        }

        var evidence = [cycleEvidence]
        let historyMatchesLiveWindow = quality.state == .stable
            && active.last.map {
                abs($0.usedPercent - window.usedPercent) <= 1.5
                    && abs($0.canonicalResetAt.timeIntervalSince(window.resetsAt)) <= WeeklyQualityEngine.resetClusterTolerance
            } == true
        if historyMatchesLiveWindow {
            if let recent = WeeklyPaceEvidence.recent(observations: active, now: now) {
                evidence.append(recent)
            }
            if let activity = WeeklyPaceEvidence.activity(observations: active, now: now) {
                evidence.append(activity)
            }
            if let currentCycleID = active.last?.cycleID,
               let historical = WeeklyPaceEvidence.historical(
                    observations: quality.observations,
                    currentCycleID: currentCycleID
               ) {
                evidence.append(historical)
            }
        }

        guard let pace = WeeklyPaceEvidence.fuse(evidence) else {
            return unavailable(
                used: window.usedPercent,
                remaining: window.remainingPercent,
                elapsed: elapsed,
                daysRemaining: daysRemaining
            )
        }
        let projected = PercentageBand(
            lower: window.remainingPercent - pace.upper * daysRemaining,
            upper: window.remainingPercent - pace.lower * daysRemaining
        )
        let exhaustion = exhaustionRange(
            remaining: window.remainingPercent,
            pace: pace,
            now: now
        )
        let transitionCount = historyMatchesLiveWindow
            ? WeeklyPaceEvidence.countUpwardTransitions(active)
            : 0
        let confidence = forecastConfidence(
            active,
            evidence: evidence,
            transitionCount: transitionCount
        )
        let state: WeeklyRunwayState
        if evidence.count == 1 || transitionCount == 0 {
            state = .earlyEstimate
        } else if projected.upper < 0 {
            state = .mayRunOut
        } else if projected.lower <= 0 || evidenceContainsMaterialOverspeed(evidence, sustainable: sustainable) {
            state = .watch
        } else {
            state = .enough
        }

        return WeeklyRunwayForecast(
            state: state,
            confidence: confidence,
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            elapsedPercent: elapsed,
            daysUntilReset: daysRemaining,
            sustainableRatePerDay: sustainable,
            recentRateBandPerDay: evidence.first(where: { $0.kind == .recent })?.bandPerDay,
            cycleRateBandPerDay: cycleEvidence.bandPerDay,
            last24HourUsageBand: last24HourUsage,
            projectedRemainingBandAtReset: projected,
            estimatedEmptyAtRange: exhaustion,
            next24HourBudget: budget,
            currentCycleTrend: trend,
            paceEvidence: evidence,
            confidenceReason: confidenceReason(
                confidence: confidence,
                evidence: evidence,
                transitionCount: transitionCount
            )
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

    private static func forecastConfidence(
        _ observations: [WeeklyObservation],
        evidence: [PaceEvidence],
        transitionCount: Int
    ) -> ForecastConfidence {
        guard evidence.count > 1,
              transitionCount > 0,
              let first = observations.first,
              let last = observations.last else {
            return .low
        }
        let coverage = last.fetchedAt.timeIntervalSince(first.fetchedAt)
        if coverage >= recentHorizon,
           transitionCount >= 3,
           evidenceAgreement(evidence) <= 0.5 {
            return .high
        }
        return .medium
    }

    private static func evidenceAgreement(_ evidence: [PaceEvidence]) -> Double {
        let midpoints = evidence.map { ($0.bandPerDay.lower + $0.bandPerDay.upper) / 2 }
        guard let lower = midpoints.min(), let upper = midpoints.max() else { return .infinity }
        return (upper - lower) / max(1, midpoints.reduce(0, +) / Double(midpoints.count))
    }

    private static func evidenceContainsMaterialOverspeed(
        _ evidence: [PaceEvidence],
        sustainable: Double
    ) -> Bool {
        guard sustainable > 0 else { return true }
        return evidence.contains {
            $0.reliability >= 0.20
                && ($0.bandPerDay.lower + $0.bandPerDay.upper) / 2 > sustainable * 1.15
        }
    }

    private static func confidenceReason(
        confidence: ForecastConfidence,
        evidence: [PaceEvidence],
        transitionCount: Int
    ) -> String {
        if evidence.count == 1 { return "cycle-only" }
        if confidence == .high { return "multi-source-agreement" }
        return "transitions:\(transitionCount)"
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

    private static func last24HourUsageBand(
        _ observations: [WeeklyObservation],
        now: Date
    ) -> PercentageBand? {
        guard let latest = observations.last else { return nil }
        let cutoff = now.addingTimeInterval(-recentHorizon)
        guard let baseline = observations.last(where: { $0.fetchedAt <= cutoff }),
              cutoff.timeIntervalSince(baseline.fetchedAt) <= 3 * 60 * 60,
              latest.fetchedAt > baseline.fetchedAt else {
            return nil
        }
        let first = WeeklyPaceEvidence.quantizedInterval(baseline.usedPercent)
        let last = WeeklyPaceEvidence.quantizedInterval(latest.usedPercent)
        return PercentageBand(
            lower: max(0, last.lower - first.upper),
            upper: max(0, last.upper - first.lower)
        )
    }

    private static func trendPoints(
        _ observations: [WeeklyObservation],
        limit: Int = 32
    ) -> [WeeklyTrendPoint] {
        guard observations.count > limit, limit > 1 else {
            return observations.map { WeeklyTrendPoint(at: $0.fetchedAt, usedPercent: $0.usedPercent) }
        }
        let stride = Double(observations.count - 1) / Double(limit - 1)
        var indexes = (0..<limit).map { Int((Double($0) * stride).rounded()) }
        indexes[indexes.count - 1] = observations.count - 1
        return indexes.map { index in
            let observation = observations[index]
            return WeeklyTrendPoint(at: observation.fetchedAt, usedPercent: observation.usedPercent)
        }
    }

    private static func calibrating(
        window: QuotaWindow,
        elapsed: Double,
        daysRemaining: Double,
        sustainable: Double,
        budget: Double,
        cycleBand: PaceBand? = nil,
        last24HourUsageBand: PercentageBand? = nil,
        trend: [WeeklyTrendPoint] = []
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
            last24HourUsageBand: last24HourUsageBand,
            projectedRemainingBandAtReset: nil,
            estimatedEmptyAtRange: nil,
            next24HourBudget: budget,
            currentCycleTrend: trend
        )
    }

    private static func calibratingFromAcceptedObservation(
        _ observations: [WeeklyObservation],
        windowMinutes: Int,
        now: Date
    ) -> WeeklyRunwayForecast {
        guard let accepted = observations.last else { return unavailable() }
        let window = QuotaWindow(
            label: "weekly",
            windowMinutes: windowMinutes,
            usedPercent: accepted.usedPercent,
            remainingPercent: accepted.remainingPercent,
            resetsAt: accepted.canonicalResetAt
        )
        guard isValid(window, now: now) else { return unavailable() }
        let daysRemaining = window.resetsAt.timeIntervalSince(now) / 86_400
        let elapsed = elapsedPercent(window: window, now: now)
        let sustainable = window.remainingPercent / daysRemaining
        let budget = min(window.remainingPercent, sustainable * min(1, daysRemaining))
        let active = activeCycleAndSegment(observations)
        return calibrating(
            window: window,
            elapsed: elapsed,
            daysRemaining: daysRemaining,
            sustainable: sustainable,
            budget: budget,
            last24HourUsageBand: last24HourUsageBand(active, now: now),
            trend: trendPoints(active)
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
