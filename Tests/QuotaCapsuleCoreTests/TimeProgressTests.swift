import Foundation
import Testing
@testable import QuotaCapsuleCore

struct TimeProgressTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    private let start = ISO8601DateFormatter().date(from: "2026-09-20T00:00:00Z")!

    @Test func sharedStartAndEndWithRestAtBeginning() throws {
        let end = start.addingTimeInterval(86400)
        let p = try #require(TimeProgress.make(start: start, end: end, now: start.addingTimeInterval(9*3600), plan: UsagePlan(), calendar: calendar))
        #expect(p.natural == 37.5)
        #expect(p.available == 0)
        let finished = try #require(TimeProgress.make(start: start, end: end, now: end, plan: UsagePlan(), calendar: calendar))
        #expect(finished.natural == 100)
        #expect(finished.available == 100)
    }

    @Test func availableLeadsDuringDayAndPausesAtNight() throws {
        let end = start.addingTimeInterval(86400)
        let a = try #require(TimeProgress.make(start: start, end: end, now: start.addingTimeInterval(23*3600), plan: UsagePlan(), calendar: calendar))
        let b = try #require(TimeProgress.make(start: start, end: end, now: start.addingTimeInterval(23.5*3600), plan: UsagePlan(), calendar: calendar))
        #expect(a.available == 100)
        #expect(a.available == b.available)
        #expect(b.natural > a.natural)
    }

    @Test func noScheduledTimeIsUnknownNotZero() throws {
        let p = try #require(TimeProgress.make(start: start, end: start.addingTimeInterval(8*3600), now: start.addingTimeInterval(3600), plan: UsagePlan(), calendar: calendar))
        #expect(p.available == nil)
        #expect(TimeProgress.make(start: start, end: start, now: start, plan: UsagePlan(), calendar: calendar) == nil)
    }

    @Test func fullDayMatchesAndWeightsDoNotChangeClock() throws {
        var plan = UsagePlan(startHour: 0, endHour: 0)
        plan.todayWeight = 2
        plan.weightDate = "2026-09-20"
        let p = try #require(TimeProgress.make(start: start, end: start.addingTimeInterval(3*86400), now: start.addingTimeInterval(86400), plan: plan, calendar: calendar))
        #expect(abs(p.natural - (p.available ?? 0)) < 0.0001)
    }

    @Test func overnightScheduleAndDeadlineClipping() throws {
        let end = start.addingTimeInterval(12*3600)
        let p = try #require(TimeProgress.make(start: start, end: end, now: start.addingTimeInterval(3*3600),
            plan: UsagePlan(startHour: 22, endHour: 6), calendar: calendar))
        #expect(p.natural == 25)
        #expect(p.available == 50)
    }

    @Test func daylightSavingUsesActualSeconds() throws {
        var c = calendar; c.timeZone = TimeZone(identifier: "America/New_York")!
        let a = ISO8601DateFormatter().date(from: "2026-03-08T05:00:00Z")!
        let b = ISO8601DateFormatter().date(from: "2026-03-09T04:00:00Z")!
        let p = try #require(TimeProgress.make(start: a, end: b, now: a.addingTimeInterval(6*3600),
            plan: UsagePlan(startHour: 0, endHour: 0), calendar: c))
        #expect(abs(p.natural - 600.0/23) < 0.001)
        #expect(p.natural == p.available)
    }
}
