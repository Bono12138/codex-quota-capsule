@testable import QuotaCapsuleCore
import Foundation
import Testing

@Suite("Weekly display model")
struct WeeklyDisplayModelTests {
    private func forecast(
        state: WeeklyRunwayState = .enough,
        confidence: ForecastConfidence = .medium,
        used: Double? = 28,
        remaining: Double? = 72,
        elapsed: Double? = 42,
        recent: PaceBand? = PaceBand(lower: 6, upper: 8),
        last24: PercentageBand? = PercentageBand(lower: 4, upper: 6),
        projected: PercentageBand? = PercentageBand(lower: 16, upper: 23),
        budget: Double? = 12
    ) -> WeeklyRunwayForecast {
        WeeklyRunwayForecast(
            state: state,
            confidence: confidence,
            usedPercent: used,
            remainingPercent: remaining,
            elapsedPercent: elapsed,
            daysUntilReset: 4,
            sustainableRatePerDay: 12,
            recentRateBandPerDay: recent,
            cycleRateBandPerDay: recent,
            last24HourUsageBand: last24,
            projectedRemainingBandAtReset: projected,
            estimatedEmptyAtRange: nil,
            next24HourBudget: budget
        )
    }

    @Test("Simplified Chinese on-track copy is weekly and actionable")
    func onTrackChineseDisplay() {
        let model = CapsuleDisplayModel.make(forecast: forecast(), locale: .zhHans)

        #expect(model.statusLabel == "够用")
        #expect(model.defaultText.contains("刷新时预计剩"))
        #expect(!model.defaultText.contains("5 小时"))
        #expect(model.metrics.map(\.label) == ["本周时间", "本周已用", "最近 24 小时", "未来 24 小时建议"])
        #expect(model.metrics[2].value == "4–6%")
        #expect(model.metrics.map(\.value) == ["42%", "28%", "4–6%", "≤12%"])
        #expect(model.confidenceText == "预测可信度：中")
    }

    @Test("calibration copy makes no runway claim")
    func calibrationIsHonest() {
        let model = CapsuleDisplayModel.make(
            forecast: forecast(state: .calibrating, confidence: .low, recent: nil, last24: nil, projected: nil),
            locale: .zhHans
        )

        #expect(model.statusLabel == "正在校准")
        #expect(model.defaultText.contains("周速度"))
        #expect(!model.defaultText.contains("预计剩"))
        #expect(model.metrics[2].value == "积累中")
        #expect(model.confidenceText.isEmpty)
    }

    @Test("risk states use distinct, non-alarmist conclusions")
    func riskStatesAreDistinct() {
        let watch = CapsuleDisplayModel.make(
            forecast: forecast(state: .watch, projected: PercentageBand(lower: -4, upper: 6)),
            locale: .zhHans
        )
        let risk = CapsuleDisplayModel.make(
            forecast: forecast(state: .mayRunOut, projected: PercentageBand(lower: -20, upper: -2)),
            locale: .zhHans
        )
        let exhausted = CapsuleDisplayModel.make(
            forecast: forecast(state: .exhausted, used: 100, remaining: 0, projected: PercentageBand(lower: 0, upper: 0), budget: 0),
            locale: .zhHans
        )

        #expect(watch.statusLabel == "偏快")
        #expect(risk.statusLabel == "可能不够")
        #expect(exhausted.statusLabel == "已用尽")
        #expect(!watch.defaultText.contains("-"))
    }

    @Test("all locales remain Weekly Only")
    func allLocalesAreWeeklyOnly() {
        let models = [QuotaLocale.zhHans, .zhHant, .en].map {
            CapsuleDisplayModel.make(forecast: forecast(), locale: $0)
        }

        #expect(models[1].metrics.map(\.label) == ["本週時間", "本週已用", "最近 24 小時", "未來 24 小時建議"])
        #expect(models[2].metrics.map(\.label) == ["Week elapsed", "Used this week", "Last 24 hours", "Next 24-hour budget"])
        #expect(models.allSatisfy { !$0.defaultText.lowercased().contains("5-hour") })
        #expect(models.allSatisfy { !$0.defaultText.contains("5 小时") && !$0.defaultText.contains("5 小時") })
    }

    @Test("onboarding teaches the weekly decision hierarchy")
    func onboardingTeachesWeeklyHierarchy() {
        let copy = QuotaCopy(locale: .zhHans)

        #expect(copy.onboardingSubtitle.contains("周额度"))
        #expect(copy.onboardingDetailStepBody.contains("最近 24 小时"))
        #expect(copy.onboardingDetailStepBody.contains("未来 24 小时建议"))
        #expect(copy.onboardingWeeklyStepTitle == "周速度是主判断")
        #expect(copy.onboardingMenuStepBody.contains("本周已用"))
        #expect(copy.weeklyTrendTitle == "本周趋势")
        #expect(copy.sustainableLineTitle.contains("5%"))
        #expect(copy.forecastResetBandTitle.contains("刷新余量"))
    }

    @Test("stale presentation freezes percentages and suppresses runway claims")
    func stalePresentationIsNonReassuring() {
        let model = CapsuleDisplayModel.makeStale(
            lastSuccessfulForecast: forecast(),
            locale: .zhHans
        )

        #expect(model.tone == .unknown)
        #expect(model.statusLabel == "已过期")
        #expect(model.defaultText.contains("上次成功"))
        #expect(model.metrics[0].value == "42%")
        #expect(model.metrics[1].value == "28%")
        #expect(model.metrics[2].value == "暂不判断")
        #expect(model.metrics[3].value == "暂不判断")
        #expect(model.usedQuotaText == "28%")
    }

    @Test("non-finite and negative values never reach display strings")
    func invalidNumbersAreSanitized() {
        let model = CapsuleDisplayModel.make(
            forecast: forecast(
                used: .nan,
                remaining: .infinity,
                elapsed: -20,
                recent: PaceBand(lower: -.infinity, upper: .nan),
                projected: PercentageBand(lower: -.infinity, upper: .infinity),
                budget: -4
            ),
            locale: .en
        )
        let text = ([model.defaultText, model.compactDetail, model.confidenceText] + model.metrics.map(\.value))
            .joined(separator: " ")
            .lowercased()

        #expect(!text.contains("nan"))
        #expect(!text.contains("inf"))
        #expect(!text.contains("-"))
    }
}
