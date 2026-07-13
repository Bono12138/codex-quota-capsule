import Foundation

public enum WeeklyPaceEvidence {
    private static let day: TimeInterval = 86_400
    private static let minimumPairSeparation: TimeInterval = 30 * 60
    private static let recentHorizon: TimeInterval = 24 * 60 * 60

    public static func cycle(window: QuotaWindow, now: Date) -> PaceEvidence? {
        let duration = Double(window.windowMinutes) * 60
        let cycleStart = window.resetsAt.addingTimeInterval(-duration)
        let elapsed = now.timeIntervalSince(cycleStart)
        guard duration > 0,
              elapsed > 0,
              elapsed <= duration,
              window.resetsAt > now,
              window.usedPercent.isFinite,
              (0...100).contains(window.usedPercent) else {
            return nil
        }

        let interval = quantizedInterval(window.usedPercent)
        let elapsedDays = elapsed / day
        let elapsedFraction = min(1, max(0, elapsed / duration))
        return PaceEvidence(
            kind: .cycle,
            bandPerDay: PaceBand(
                lower: interval.lower / elapsedDays,
                upper: interval.upper / elapsedDays
            ),
            reliability: clamp(0.10 + 0.45 * sqrt(elapsedFraction), lower: 0.10, upper: 0.55),
            transitionCount: 0,
            coverageHours: elapsed / 3_600
        )
    }

    public static func recent(
        observations: [WeeklyObservation],
        now: Date
    ) -> PaceEvidence? {
        let cutoff = now.addingTimeInterval(-recentHorizon)
        let eligible = observations.filter { $0.fetchedAt >= cutoff && $0.fetchedAt <= now }
        let transitions = countUpwardTransitions(eligible)
        guard transitions > 0,
              let first = eligible.first,
              let last = eligible.last,
              let band = robustBand(eligible) else {
            return nil
        }
        let coverage = last.fetchedAt.timeIntervalSince(first.fetchedAt)
        let reliability = clamp(
            0.20
                + 0.10 * Double(min(transitions, 4))
                + 0.25 * sqrt(min(1, coverage / recentHorizon)),
            lower: 0.20,
            upper: 0.85
        )
        return PaceEvidence(
            kind: .recent,
            bandPerDay: band,
            reliability: reliability,
            transitionCount: transitions,
            coverageHours: coverage / 3_600
        )
    }

    public static func activity(
        observations: [WeeklyObservation],
        now: Date
    ) -> PaceEvidence? {
        let eligible = observations.filter { $0.fetchedAt <= now }
        let transitionIndexes = eligible.indices.dropFirst().filter {
            eligible[$0].usedPercent > eligible[$0 - 1].usedPercent
        }
        guard let firstTransition = transitionIndexes.first,
              let lastTransition = transitionIndexes.last else {
            return nil
        }

        let baseline = eligible[firstTransition - 1]
        let latestTransition = eligible[lastTransition]
        let coverage = now.timeIntervalSince(baseline.fetchedAt)
        guard coverage >= minimumPairSeparation else { return nil }

        let first = quantizedInterval(baseline.usedPercent)
        let last = quantizedInterval(latestTransition.usedPercent)
        let scale = day / coverage
        let band = PaceBand(
            lower: max(0, last.lower - first.upper) * scale,
            upper: max(0, last.upper - first.lower) * scale
        )
        guard band.upper > 0 else { return nil }

        let idle = max(0, now.timeIntervalSince(latestTransition.fetchedAt))
        let idleFactor = max(0.5, exp(-idle / (48 * 3_600)))
        let reliability = clamp(
            (0.18
                + 0.08 * Double(min(transitionIndexes.count, 4))
                + 0.18 * sqrt(min(1, coverage / recentHorizon))) * idleFactor,
            lower: 0.12,
            upper: 0.72
        )
        return PaceEvidence(
            kind: .activity,
            bandPerDay: band,
            reliability: reliability,
            transitionCount: transitionIndexes.count,
            coverageHours: coverage / 3_600
        )
    }

    public static func historical(
        observations: [WeeklyObservation],
        currentCycleID: Int
    ) -> PaceEvidence? {
        var candidates: [(band: PaceBand, reliability: Double, transitions: Int, coverage: TimeInterval)] = []
        let completedCycles = Dictionary(grouping: observations.filter { $0.cycleID != currentCycleID }, by: \.cycleID)

        for cycle in completedCycles.values {
            let segments = Dictionary(grouping: cycle, by: \.segmentID).values
            let candidate = segments.compactMap { segment -> (PaceBand, Int, TimeInterval)? in
                let ordered = segment.sorted { $0.fetchedAt < $1.fetchedAt }
                guard let first = ordered.first, let last = ordered.last else { return nil }
                let coverage = last.fetchedAt.timeIntervalSince(first.fetchedAt)
                let transitions = countUpwardTransitions(ordered)
                guard coverage >= 48 * 3_600, transitions >= 2 else { return nil }
                let start = quantizedInterval(first.usedPercent)
                let end = quantizedInterval(last.usedPercent)
                let scale = day / coverage
                return (
                    PaceBand(
                        lower: max(0, end.lower - start.upper) * scale,
                        upper: max(0, end.upper - start.lower) * scale
                    ),
                    transitions,
                    coverage
                )
            }.max { $0.2 < $1.2 }

            if let candidate {
                let reliability = clamp(
                    0.15
                        + 0.03 * Double(min(candidate.1, 4))
                        + 0.08 * min(1, candidate.2 / (7 * day)),
                    lower: 0.15,
                    upper: 0.35
                )
                candidates.append((candidate.0, reliability, candidate.1, candidate.2))
            }
        }

        guard !candidates.isEmpty else { return nil }
        return PaceEvidence(
            kind: .historical,
            bandPerDay: PaceBand(
                lower: median(candidates.map { $0.band.lower }),
                upper: median(candidates.map { $0.band.upper })
            ),
            reliability: min(0.35, candidates.map(\.reliability).reduce(0, +) / Double(candidates.count)),
            transitionCount: candidates.map(\.transitions).reduce(0, +),
            coverageHours: (candidates.map(\.coverage).max() ?? 0) / 3_600
        )
    }

    public static func fuse(_ evidence: [PaceEvidence]) -> PaceBand? {
        guard !evidence.isEmpty else { return nil }
        return PaceBand(
            lower: weightedQuantile(evidence.map { ($0.bandPerDay.lower, $0.reliability) }, quantile: 0.25),
            upper: weightedQuantile(evidence.map { ($0.bandPerDay.upper, $0.reliability) }, quantile: 0.75)
        )
    }

    public static func countUpwardTransitions(_ observations: [WeeklyObservation]) -> Int {
        zip(observations, observations.dropFirst()).reduce(into: 0) { count, pair in
            if pair.1.usedPercent > pair.0.usedPercent {
                count += 1
            }
        }
    }

    static func quantizedInterval(_ value: Double) -> PercentageBand {
        PercentageBand(
            lower: max(0, value - 0.5),
            upper: min(100, value + 0.5)
        )
    }

    private static func robustBand(_ observations: [WeeklyObservation]) -> PaceBand? {
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
                let scale = day / duration
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

    private static func weightedQuantile(
        _ values: [(value: Double, weight: Double)],
        quantile: Double
    ) -> Double {
        let ordered = values.sorted { $0.value < $1.value }
        let total = ordered.reduce(0) { $0 + max(0.001, $1.weight) }
        var cumulative = 0.0
        for item in ordered {
            cumulative += max(0.001, item.weight)
            if cumulative >= total * quantile { return item.value }
        }
        return ordered.last?.value ?? 0
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}
