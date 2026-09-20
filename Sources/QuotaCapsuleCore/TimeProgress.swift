import Foundation

/// Both clocks share a window; scheduled hours are a plan, not observed activity.
public struct TimeProgress: Equatable, Sendable {
    public let natural: Double
    public let available: Double?

    public static func make(start: Date, end: Date, now: Date, plan: UsagePlan,
                            calendar: Calendar = .current) -> TimeProgress? {
        let duration = end.timeIntervalSince(start)
        guard duration.isFinite, duration > 0, duration <= 9 * 86400 else { return nil }
        let instant = min(end, max(start, now))
        let slots = UsageBudgetPlanner.sessions(plan: plan, from: start, to: end, calendar: calendar)
        let total = slots.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        let elapsed = slots.reduce(0.0) { $0 + max(0, min(instant, $1.end).timeIntervalSince($1.start)) }
        return TimeProgress(natural: instant.timeIntervalSince(start) / duration * 100,
                            available: total > 0 ? min(100, elapsed / total * 100) : nil)
    }
}
