import Foundation

public enum WeeklyQualityEngine {
    public static let resetClusterTolerance: TimeInterval = 300
    public static let freshnessThreshold: TimeInterval = 180
    public static let confirmationCount = 3
    public static let confirmationSpan: TimeInterval = 120
    public static let correctionDrop = 2.0

    public static func analyze(
        _ readings: [WeeklyQuotaReading],
        now: Date = Date()
    ) -> WeeklyQualityResult {
        let ordered = readings
            .filter { isUsable($0, now: now) }
            .sorted { lhs, rhs in
                if lhs.fetchedAt == rhs.fetchedAt {
                    return lhs.resetsAt < rhs.resetsAt
                }
                return lhs.fetchedAt < rhs.fetchedAt
            }

        guard let latest = ordered.last else {
            return WeeklyQualityResult(
                state: .unavailable,
                observations: [],
                canonicalResetAt: nil,
                flags: []
            )
        }

        if now.timeIntervalSince(latest.fetchedAt) > freshnessThreshold {
            let lastObservation = observation(
                from: latest,
                canonicalResetAt: latest.resetsAt,
                cycleID: 0,
                segmentID: 0,
                flags: [.staleSource]
            )
            return WeeklyQualityResult(
                state: .stale,
                observations: [lastObservation],
                canonicalResetAt: latest.resetsAt,
                flags: [.staleSource]
            )
        }

        if hasAlternatingTail(ordered) {
            let first = ordered[ordered.count - 5]
            return WeeklyQualityResult(
                state: .unstable,
                observations: [observation(from: first, canonicalResetAt: first.resetsAt, cycleID: 0, segmentID: 0)],
                canonicalResetAt: first.resetsAt,
                flags: [.alternatingStream]
            )
        }

        var accepted: [WeeklyObservation] = []
        var flags: Set<WeeklyQualityFlag> = []
        var activeResetSamples: [Date] = []
        var activeReset: Date?
        var cycleID = 0
        var segmentID = 0
        var pendingCycle: [WeeklyQuotaReading] = []
        var pendingCorrection: [WeeklyQuotaReading] = []
        var calibrating = false

        for reading in ordered {
            guard let currentReset = activeReset, let lastAccepted = accepted.last else {
                activeResetSamples = [reading.resetsAt]
                activeReset = reading.resetsAt
                accepted.append(observation(from: reading, canonicalResetAt: reading.resetsAt, cycleID: cycleID, segmentID: segmentID))
                continue
            }

            let sameResetCluster = abs(reading.resetsAt.timeIntervalSince(currentReset)) <= resetClusterTolerance
            if !sameResetCluster {
                let resetMovedForward = reading.resetsAt.timeIntervalSince(currentReset) >= 6 * 60 * 60
                let usageDropped = lastAccepted.usedPercent - reading.usedPercent >= correctionDrop

                guard resetMovedForward || usageDropped else {
                    flags.insert(.resetCandidate)
                    calibrating = true
                    continue
                }

                if pendingCycle.isEmpty || abs(reading.resetsAt.timeIntervalSince(pendingCycle[0].resetsAt)) <= resetClusterTolerance {
                    pendingCycle.append(reading)
                } else {
                    pendingCycle = [reading]
                }
                flags.insert(.resetCandidate)

                if isConfirmed(pendingCycle) {
                    cycleID += 1
                    segmentID += 1
                    activeResetSamples = pendingCycle.map(\.resetsAt)
                    let canonical = median(activeResetSamples)
                    activeReset = canonical
                    if activeResetSamples.contains(where: { $0 != canonical }) {
                        flags.insert(.resetJitter)
                    }
                    accepted.append(contentsOf: pendingCycle.map {
                        observation(
                            from: $0,
                            canonicalResetAt: canonical,
                            cycleID: cycleID,
                            segmentID: segmentID,
                            flags: [.resetCandidate]
                        )
                    })
                    pendingCycle.removeAll()
                    pendingCorrection.removeAll()
                    calibrating = false
                } else {
                    calibrating = true
                }
                continue
            }

            pendingCycle.removeAll()
            activeResetSamples.append(reading.resetsAt)
            let canonical = median(activeResetSamples)
            if activeResetSamples.contains(where: { $0 != canonical }) {
                flags.insert(.resetJitter)
            }
            activeReset = canonical
            accepted = accepted.map { existing in
                guard existing.cycleID == cycleID else { return existing }
                return WeeklyObservation(
                    fetchedAt: existing.fetchedAt,
                    canonicalResetAt: canonical,
                    usedPercent: existing.usedPercent,
                    remainingPercent: existing.remainingPercent,
                    cycleID: existing.cycleID,
                    segmentID: existing.segmentID,
                    qualityFlags: existing.qualityFlags
                )
            }

            if reading.usedPercent < lastAccepted.usedPercent {
                if pendingCorrection.isEmpty || reading.usedPercent >= pendingCorrection.last!.usedPercent {
                    pendingCorrection.append(reading)
                } else {
                    pendingCorrection = [reading]
                }
                flags.insert(.correction)

                if isConfirmed(pendingCorrection) {
                    segmentID += 1
                    accepted.append(contentsOf: pendingCorrection.map {
                        observation(
                            from: $0,
                            canonicalResetAt: canonical,
                            cycleID: cycleID,
                            segmentID: segmentID,
                            flags: [.correction]
                        )
                    })
                    pendingCorrection.removeAll()
                    calibrating = false
                } else {
                    calibrating = true
                }
                continue
            }

            pendingCorrection.removeAll()
            calibrating = false
            accepted.append(observation(from: reading, canonicalResetAt: canonical, cycleID: cycleID, segmentID: segmentID))
        }

        return WeeklyQualityResult(
            state: calibrating ? .calibrating : .stable,
            observations: sampledForForecasting(accepted),
            canonicalResetAt: activeReset,
            flags: flags
        )
    }

    private static func isUsable(_ reading: WeeklyQuotaReading, now: Date) -> Bool {
        reading.sourceStatus == .ok
            && reading.usedPercent.isFinite
            && reading.remainingPercent.isFinite
            && (0...100).contains(reading.usedPercent)
            && (0...100).contains(reading.remainingPercent)
            && abs(reading.usedPercent + reading.remainingPercent - 100) <= 1.5
            && abs(reading.windowMinutes - 10_080) <= 60
            && reading.fetchedAt.timeIntervalSince(now) <= 60
            && reading.resetsAt > reading.fetchedAt
            && reading.resetsAt.timeIntervalSince(reading.fetchedAt) <= 8 * 24 * 60 * 60
    }

    private static func sampledForForecasting(_ observations: [WeeklyObservation]) -> [WeeklyObservation] {
        var sampled: [WeeklyObservation] = []
        for observation in observations {
            guard let previous = sampled.last else {
                sampled.append(observation)
                continue
            }
            let bucket = Int(observation.fetchedAt.timeIntervalSince1970 / 300)
            let previousBucket = Int(previous.fetchedAt.timeIntervalSince1970 / 300)
            let isTransition = observation.usedPercent != previous.usedPercent
                || observation.cycleID != previous.cycleID
                || observation.segmentID != previous.segmentID
            let isEvent = !observation.qualityFlags.isEmpty
            if bucket != previousBucket || isTransition || isEvent {
                sampled.append(observation)
            }
        }
        return sampled
    }

    private static func isConfirmed(_ readings: [WeeklyQuotaReading]) -> Bool {
        guard readings.count >= confirmationCount,
              let first = readings.first,
              let last = readings.last else {
            return false
        }
        return last.fetchedAt.timeIntervalSince(first.fetchedAt) >= confirmationSpan
    }

    private static func hasAlternatingTail(_ readings: [WeeklyQuotaReading]) -> Bool {
        guard readings.count >= 5 else { return false }
        let tail = Array(readings.suffix(5))
        let sameA = sameStream(tail[0], tail[2]) && sameStream(tail[2], tail[4])
        let sameB = sameStream(tail[1], tail[3])
        let distinct = !sameStream(tail[0], tail[1])
        return sameA && sameB && distinct
    }

    private static func sameStream(_ lhs: WeeklyQuotaReading, _ rhs: WeeklyQuotaReading) -> Bool {
        abs(lhs.usedPercent - rhs.usedPercent) < 0.5
            && abs(lhs.resetsAt.timeIntervalSince(rhs.resetsAt)) <= resetClusterTolerance
    }

    private static func observation(
        from reading: WeeklyQuotaReading,
        canonicalResetAt: Date,
        cycleID: Int,
        segmentID: Int,
        flags: Set<WeeklyQualityFlag> = []
    ) -> WeeklyObservation {
        WeeklyObservation(
            fetchedAt: reading.fetchedAt,
            canonicalResetAt: canonicalResetAt,
            usedPercent: reading.usedPercent,
            remainingPercent: reading.remainingPercent,
            cycleID: cycleID,
            segmentID: segmentID,
            qualityFlags: flags
        )
    }

    private static func median(_ dates: [Date]) -> Date {
        let sorted = dates.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return Date(timeIntervalSince1970: (sorted[middle - 1].timeIntervalSince1970 + sorted[middle].timeIntervalSince1970) / 2)
        }
        return sorted[middle]
    }
}
