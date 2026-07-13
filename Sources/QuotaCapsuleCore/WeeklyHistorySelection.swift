import Foundation

public enum WeeklyHistorySelection {
    public static let horizon: TimeInterval = 15 * 24 * 60 * 60
    public static let flatBucket: TimeInterval = 15 * 60
    public static let defaultLimit = 2_500

    public static func compact(
        _ readings: [WeeklyQuotaReading],
        now: Date = Date(),
        limit: Int = defaultLimit
    ) -> [WeeklyQuotaReading] {
        let cutoff = now.addingTimeInterval(-horizon)
        let ordered = readings
            .filter { $0.fetchedAt >= cutoff && $0.fetchedAt <= now.addingTimeInterval(60) }
            .sorted { lhs, rhs in
                if lhs.fetchedAt == rhs.fetchedAt {
                    return lhs.resetsAt < rhs.resetsAt
                }
                return lhs.fetchedAt < rhs.fetchedAt
            }

        var compacted: [WeeklyQuotaReading] = []
        var previousRaw: WeeklyQuotaReading?
        for reading in ordered {
            guard let lastCompacted = compacted.last, let previous = previousRaw else {
                compacted.append(reading)
                previousRaw = reading
                continue
            }

            let bucket = Int(reading.fetchedAt.timeIntervalSince1970 / flatBucket)
            let previousBucket = Int(lastCompacted.fetchedAt.timeIntervalSince1970 / flatBucket)
            let isTransition = reading.usedPercent != previous.usedPercent
                || reading.remainingPercent != previous.remainingPercent
                || reading.resetsAt != previous.resetsAt
                || reading.sourceStatus != previous.sourceStatus
            if bucket != previousBucket || isTransition {
                compacted.append(reading)
            }
            previousRaw = reading
        }

        if let latest = ordered.last, compacted.last?.fetchedAt != latest.fetchedAt {
            compacted.append(latest)
        }

        return Array(compacted.suffix(max(1, limit)))
    }
}
