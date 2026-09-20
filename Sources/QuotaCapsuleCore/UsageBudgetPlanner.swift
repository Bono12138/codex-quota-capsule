import Foundation

public struct UsagePlan: Codable, Equatable, Sendable {
    public var startHour: Int
    public var endHour: Int
    public var weekdays: Set<Int>
    public var reservePercent: Double
    public var todayWeight: Double = 1
    public var weightDate: String = ""

    public init(startHour: Int = 9, endHour: Int = 23, weekdays: Set<Int> = [1,2,3,4,5,6,7], reservePercent: Double = 0) {
        self.startHour = startHour; self.endHour = endHour
        self.weekdays = weekdays; self.reservePercent = reservePercent
    }
}

public struct UsageSession: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let weight: Double
    public var hours: Double { end.timeIntervalSince(start) / 3600 }
}

public struct UsageBudgetAnchor: Codable, Equatable, Sendable {
    public let plan: UsagePlan
    public let timeZone: String
    public let at: Date
    public let end: Date
    public let resetAt: Date
    public let horizon: Date
    public let initialRemaining: Double
    public let allocation: Double
}

public enum UsageBudgetStatus: String, Sendable {
    case active, upcoming, noSession, allocatedSpent, reserved, unavailable
}

public struct UsageBudget: Sendable {
    public let state: UsageBudgetStatus
    public let allowance: Double?
    public let remainingHours: Double
    public let session: UsageSession?
    public let anchor: UsageBudgetAnchor?
    public let consumed: Double

    public static let unavailable = UsageBudget(state: .unavailable, allowance: nil, remainingHours: 0, session: nil, anchor: nil, consumed: 0)
}

/// Allocates account quota to user-confirmed sessions. Observed pace never sets the budget.
public enum UsageBudgetPlanner {
    public static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func sessions(plan: UsagePlan, from: Date, to: Date, calendar: Calendar) -> [UsageSession] {
        guard to > from, to.timeIntervalSince(from) <= 9 * 86400,
              (0...23).contains(plan.startHour), (0...23).contains(plan.endHour),
              plan.todayWeight.isFinite, (0.25...4).contains(plan.todayWeight) else { return [] }
        var day = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: from))!
        var result: [UsageSession] = []
        for _ in 0..<12 {
            if day >= to { break }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            defer { day = nextDay }
            guard plan.weekdays.contains(calendar.component(.weekday, from: day)),
                  let start = calendar.date(bySettingHour: plan.startHour, minute: 0, second: 0, of: day),
                  let end = calendar.date(bySettingHour: plan.endHour, minute: 0, second: 0,
                                          of: plan.endHour <= plan.startHour ? nextDay : day) else { continue }
            let clippedStart = max(start, from), clippedEnd = min(end, to)
            guard clippedEnd > clippedStart else { continue }
            let weight = dayKey(day, calendar: calendar) == plan.weightDate ? plan.todayWeight : 1
            result.append(UsageSession(start: clippedStart, end: clippedEnd, weight: weight))
        }
        return result
    }

    public static func evaluate(plan: UsagePlan, anchor: UsageBudgetAnchor?, remaining: Double,
                                resetAt: Date, horizon: Date, now: Date, calendar: Calendar) -> UsageBudget {
        guard remaining.isFinite, (0...100).contains(remaining),
              plan.reservePercent.isFinite, (0...100).contains(plan.reservePercent),
              horizon > now, horizon <= resetAt, resetAt.timeIntervalSince(now) <= 8 * 86400 else { return .unavailable }
        let slots = sessions(plan: plan, from: now, to: horizon, calendar: calendar)
        let hours = slots.reduce(0) { $0 + $1.hours }
        guard let slot = slots.first else {
            return UsageBudget(state: .noSession, allowance: nil, remainingHours: 0, session: nil, anchor: nil, consumed: 0)
        }
        let spendable = max(0, remaining - plan.reservePercent)
        let weightedHours = slots.reduce(0) { $0 + $1.hours * $1.weight }
        let allocation = spendable * slot.hours * slot.weight / weightedHours
        guard slot.start <= now else {
            return UsageBudget(state: .upcoming, allowance: allocation, remainingHours: hours, session: slot, anchor: nil, consumed: 0)
        }
        let reusable = anchor.flatMap { a -> UsageBudgetAnchor? in
            guard a.plan == plan, a.timeZone == calendar.timeZone.identifier,
                  a.at <= now, a.end > now, abs(a.end.timeIntervalSince(slot.end)) < 60,
                  abs(a.resetAt.timeIntervalSince(resetAt)) < 60,
                  abs(a.horizon.timeIntervalSince(horizon)) < 60,
                  a.initialRemaining.isFinite, (0...100).contains(a.initialRemaining),
                  a.allocation.isFinite, (0...100).contains(a.allocation),
                  remaining <= a.initialRemaining + 0.01 else { return nil }
            return a
        }
        let locked = reusable ?? UsageBudgetAnchor(plan: plan, timeZone: calendar.timeZone.identifier,
            at: now, end: slot.end, resetAt: resetAt, horizon: horizon,
            initialRemaining: remaining, allocation: allocation)
        let consumed = max(0, locked.initialRemaining - remaining)
        let allowance = min(spendable, max(0, locked.allocation - consumed))
        let state: UsageBudgetStatus = spendable <= 0 ? .reserved : allowance <= 0 ? .allocatedSpent : .active
        return UsageBudget(state: state, allowance: allowance, remainingHours: hours,
                           session: slot, anchor: locked, consumed: consumed)
    }
}
