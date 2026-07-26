@testable import QuotaCapsuleMac
import Foundation
import QuotaCapsuleCore
import Testing

@Suite("Weekly trend horizon")
struct WeeklyTrendHorizonTests {
    @Test("chart ends at an earlier reset-credit expiry")
    func resetCreditExpiryEndsChart() {
        let naturalReset = Date(timeIntervalSince1970: 2_000_100_000)
        let creditExpiry = naturalReset.addingTimeInterval(-86_400)
        let window = QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 3,
            remainingPercent: 97,
            resetsAt: naturalReset
        )
        let forecast = WeeklyRunwayForecast(
            state: .enough,
            confidence: .medium,
            usedPercent: 3,
            remainingPercent: 97,
            elapsedPercent: 60,
            daysUntilReset: 1,
            sustainableRatePerDay: 97,
            recentRateBandPerDay: nil,
            cycleRateBandPerDay: nil,
            projectedRemainingBandAtReset: PercentageBand(lower: 95, upper: 95),
            estimatedEmptyAtRange: nil,
            next24HourBudget: 97,
            burnHorizonAt: creditExpiry,
            burnHorizonSource: .resetCreditExpiry
        )

        let horizon = WeeklyTrendHorizon.make(forecast: forecast, window: window)

        #expect(horizon.at == creditExpiry)
        #expect(horizon.source == .resetCreditExpiry)
    }

    @Test("chart falls back to the natural weekly reset")
    func naturalResetEndsChart() {
        let naturalReset = Date(timeIntervalSince1970: 2_000_100_000)
        let window = QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 3,
            remainingPercent: 97,
            resetsAt: naturalReset
        )
        let forecast = WeeklyRunwayForecast(
            state: .calibrating,
            confidence: .low,
            usedPercent: 3,
            remainingPercent: 97,
            elapsedPercent: 2,
            daysUntilReset: 6,
            sustainableRatePerDay: 16,
            recentRateBandPerDay: nil,
            cycleRateBandPerDay: nil,
            projectedRemainingBandAtReset: nil,
            estimatedEmptyAtRange: nil,
            next24HourBudget: 14
        )

        let horizon = WeeklyTrendHorizon.make(forecast: forecast, window: window)

        #expect(horizon.at == naturalReset)
        #expect(horizon.source == .naturalReset)
    }
}
