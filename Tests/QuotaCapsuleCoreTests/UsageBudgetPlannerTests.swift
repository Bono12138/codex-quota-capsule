import Foundation
import Testing
@testable import QuotaCapsuleCore

@Suite("Scheduled quota budget")
struct UsageBudgetPlannerTests {
    func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    var plan: UsagePlan { UsagePlan(startHour: 18, endHour: 22, weekdays: [1,2,3,4,5,6,7], reservePercent: 0) }

    @Test func proportionalBudgetAndFreeze() throws {
        let now = date("2026-09-20T18:00:00Z")
        let end = date("2026-09-22T22:00:00Z")
        let first = UsageBudgetPlanner.evaluate(plan: plan, anchor: nil, remaining: 60, resetAt: end, horizon: end, now: now, calendar: calendar)
        #expect(first.allowance == 20)
        let anchor = try #require(first.anchor)
        let later = UsageBudgetPlanner.evaluate(plan: plan, anchor: anchor, remaining: 55, resetAt: end, horizon: end, now: now.addingTimeInterval(3600), calendar: calendar)
        #expect(later.allowance == 15)
        #expect(later.anchor == anchor)
        let idle = UsageBudgetPlanner.evaluate(plan: plan, anchor: anchor, remaining: 60, resetAt: end, horizon: end, now: now.addingTimeInterval(7200), calendar: calendar)
        #expect(idle.allowance == 20)
    }

    @Test func partialSessionAndReserve() {
        var p = plan
        p.reservePercent = 10
        let r = UsageBudgetPlanner.evaluate(plan: p, anchor: nil, remaining: 40, resetAt: date("2026-09-21T22:00:00Z"), horizon: date("2026-09-21T22:00:00Z"), now: date("2026-09-20T20:00:00Z"), calendar: calendar)
        #expect(r.allowance == 10)
        #expect(r.remainingHours == 6)
    }

    @Test func sleepAndNoRemainingSession() {
        let end = date("2026-09-21T10:00:00Z")
        let r = UsageBudgetPlanner.evaluate(plan: plan, anchor: nil, remaining: 40, resetAt: end, horizon: end, now: date("2026-09-20T23:00:00Z"), calendar: calendar)
        #expect(r.state == .noSession)
        #expect(r.allowance == nil)
        #expect(r.remainingHours == 0)
    }

    @Test func overnightWeekdayBelongsToStartDate() {
        let p = UsagePlan(startHour: 22, endHour: 2, weekdays: [1], reservePercent: 0)
        let slots = UsageBudgetPlanner.sessions(plan: p, from: date("2026-09-21T00:00:00Z"), to: date("2026-09-22T00:00:00Z"), calendar: calendar)
        #expect(slots.count == 1)
        #expect(slots.first?.end == date("2026-09-21T02:00:00Z"))
    }

    @Test func daylightSavingUsesRealHours() {
        var c = calendar
        c.timeZone = TimeZone(identifier: "America/New_York")!
        let p = UsagePlan(startHour: 0, endHour: 4, weekdays: [1], reservePercent: 0)
        let slots = UsageBudgetPlanner.sessions(plan: p, from: date("2026-03-08T05:00:00Z"), to: date("2026-03-08T09:00:00Z"), calendar: c)
        #expect(slots.reduce(0) { $0 + $1.hours } == 3)
    }

    @Test func exhaustionCorrectionAndChangedEndpoint() throws {
        let now = date("2026-09-20T18:00:00Z"), end = date("2026-09-22T22:00:00Z")
        let first = UsageBudgetPlanner.evaluate(plan: plan, anchor: nil, remaining: 60, resetAt: end, horizon: end, now: now, calendar: calendar)
        let anchor = try #require(first.anchor)
        let spent = UsageBudgetPlanner.evaluate(plan: plan, anchor: anchor, remaining: 35, resetAt: end, horizon: end, now: now.addingTimeInterval(60), calendar: calendar)
        #expect(spent.allowance == 0)
        #expect(spent.state == .allocatedSpent)
        let correction = UsageBudgetPlanner.evaluate(plan: plan, anchor: anchor, remaining: 70, resetAt: end, horizon: end, now: now.addingTimeInterval(60), calendar: calendar)
        #expect(correction.anchor?.initialRemaining == 70)
        let credit = UsageBudgetPlanner.evaluate(plan: plan, anchor: anchor, remaining: 60, resetAt: end, horizon: now.addingTimeInterval(3600), now: now, calendar: calendar)
        #expect(credit.allowance == 60)
    }

    @Test func weightedTodayDoesNotChangeFutureDays() {
        var p = plan
        p.weightDate = "2026-09-20"; p.todayWeight = 2
        let now = date("2026-09-20T18:00:00Z"), end = date("2026-09-21T22:00:00Z")
        let r = UsageBudgetPlanner.evaluate(plan: p, anchor: nil, remaining: 60, resetAt: end, horizon: end, now: now, calendar: calendar)
        #expect(r.allowance == 40)
    }

    @Test func invalidInputsAndReserveCannotProduceAdvice() {
        let now = date("2026-09-20T18:00:00Z"), end = now.addingTimeInterval(3600)
        #expect(UsageBudgetPlanner.evaluate(plan: plan, anchor: nil, remaining: .nan, resetAt: end, horizon: end, now: now, calendar: calendar).state == .unavailable)
        var p = plan; p.reservePercent = 80
        #expect(UsageBudgetPlanner.evaluate(plan: p, anchor: nil, remaining: 60, resetAt: end, horizon: end, now: now, calendar: calendar).allowance == 0)
        p.weekdays = []
        #expect(UsageBudgetPlanner.evaluate(plan: p, anchor: nil, remaining: 60, resetAt: end, horizon: end, now: now, calendar: calendar).state == .noSession)
    }

    @Test func sessionsConserveBudgetAndCarryUnusedForward() throws {
        let end = date("2026-09-22T22:00:00Z")
        var remaining = 65.0
        var allocated = 0.0
        let p = UsagePlan(startHour: 18, endHour: 22, reservePercent: 5)
        for day in [20, 21, 22] {
            let now = date("2026-09-\(day)T18:00:00Z")
            let r = UsageBudgetPlanner.evaluate(plan: p, anchor: nil, remaining: remaining,
                resetAt: end, horizon: end, now: now, calendar: calendar)
            let allowance = try #require(r.allowance)
            allocated += allowance; remaining -= allowance
        }
        #expect(abs(allocated - 60) < 0.0001)
        #expect(abs(remaining - 5) < 0.0001)
        let next = UsageBudgetPlanner.evaluate(plan: p, anchor: nil, remaining: 55,
            resetAt: end, horizon: end, now: date("2026-09-21T18:00:00Z"), calendar: calendar)
        #expect(next.allowance == 25)
    }

    @Test func fullDayAndTimezoneChange() throws {
        let now = date("2026-09-20T18:00:00Z"), end = date("2026-09-21T22:00:00Z")
        let p = UsagePlan(startHour: 0, endHour: 0)
        let first = UsageBudgetPlanner.evaluate(plan: p, anchor: nil, remaining: 70,
            resetAt: end, horizon: end, now: now, calendar: calendar)
        #expect(first.remainingHours == 28)
        #expect(first.allowance == 15)
        var c = calendar; c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let moved = UsageBudgetPlanner.evaluate(plan: p, anchor: first.anchor, remaining: 70,
            resetAt: end, horizon: end, now: now, calendar: c)
        #expect(moved.anchor?.timeZone == "Asia/Shanghai")
        #expect(moved.allowance == 55)
    }
}
