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
        budget: Double? = 12,
        evidence: [PaceEvidence] = [
            PaceEvidence(kind: .cycle, bandPerDay: PaceBand(lower: 5, upper: 8), reliability: 0.4, transitionCount: 0, coverageHours: 48),
            PaceEvidence(kind: .recent, bandPerDay: PaceBand(lower: 6, upper: 8), reliability: 0.6, transitionCount: 2, coverageHours: 24),
            PaceEvidence(kind: .activity, bandPerDay: PaceBand(lower: 5, upper: 9), reliability: 0.5, transitionCount: 2, coverageHours: 30)
        ],
        confidenceReason: String = "transitions:2"
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
            next24HourBudget: budget,
            paceEvidence: evidence,
            confidenceReason: confidenceReason
        )
    }

    @Test("Simplified Chinese on-track copy is weekly and actionable")
    func onTrackChineseDisplay() {
        let model = CapsuleDisplayModel.make(forecast: forecast(), locale: .zhHans)

        #expect(model.statusLabel == "够用")
        #expect(model.defaultText.contains("重置时预计剩"))
        #expect(!model.defaultText.contains("5 小时"))
        #expect(model.metrics.map(\.label) == ["本周时间", "本周已用", "未来 24 小时建议", "最近 24 小时"])
        #expect(model.metrics[3].value == "4–6%")
        #expect(model.metrics.map(\.value) == ["42%", "28%", "≤12%", "4–6%"])
        #expect(model.confidenceText.contains("已观察到 2 次实际增长"))
        #expect(model.showsLivePaceDetails)
    }

    @Test("early estimate gives immediate value without a six-hour waiting room")
    func earlyEstimateIsImmediateAndHonest() {
        let model = CapsuleDisplayModel.make(
            forecast: forecast(
                state: .earlyEstimate,
                confidence: .low,
                recent: nil,
                last24: nil,
                projected: PercentageBand(lower: -40, upper: -20),
                evidence: [PaceEvidence(kind: .cycle, bandPerDay: PaceBand(lower: 34, upper: 38), reliability: 0.2, transitionCount: 0, coverageHours: 6)],
                confidenceReason: "cycle-only"
            ),
            locale: .zhHans
        )

        #expect(model.statusLabel == "初步估算")
        #expect(model.defaultText == "初步判断：按本周平均速度可能不够")
        #expect(model.confidenceText == "初步判断：仅依据当前周期平均速度")
        #expect(model.metrics[3].value == "积累中")
        #expect(!model.defaultText.contains("6 小时"))
        #expect(!model.confidenceText.contains("6 小时"))
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
        #expect(risk.defaultText == "照最近速度，本周额度可能在重置前用完")
        #expect(exhausted.statusLabel == "已用尽")
        #expect(exhausted.defaultText == "本周额度已用尽，重置后会自动恢复")
        #expect(!watch.defaultText.contains("-"))
    }

    @Test("all locales remain Weekly Only")
    func allLocalesAreWeeklyOnly() {
        let models = [QuotaLocale.zhHans, .zhHant, .en].map {
            CapsuleDisplayModel.make(forecast: forecast(), locale: $0)
        }

        #expect(models[1].metrics.map(\.label) == ["本週時間", "本週已用", "未來 24 小時建議", "最近 24 小時"])
        #expect(models[2].metrics.map(\.label) == ["Week elapsed", "Used this week", "Next 24-hour budget", "Last 24 hours"])
        #expect(models.allSatisfy { !$0.defaultText.lowercased().contains("5-hour") })
        #expect(models.allSatisfy { !$0.defaultText.contains("5 小时") && !$0.defaultText.contains("5 小時") })
    }

    @Test("English status labels include the evidence-driven early estimate")
    func englishStatusVocabulary() {
        let copy = QuotaCopy(locale: .en)

        #expect(copy.weeklyStatusLabel(.unavailable) == "Data unavailable")
        #expect(copy.weeklyStatusLabel(.exhausted) == "Exhausted")
        #expect(copy.weeklyStatusLabel(.calibrating) == "Calibrating")
        #expect(copy.weeklyStatusLabel(.earlyEstimate) == "Early estimate")
        #expect(copy.weeklyStatusLabel(.enough) == "On track")
        #expect(copy.weeklyStatusLabel(.watch) == "Running fast")
        #expect(copy.weeklyStatusLabel(.mayRunOut) == "May run out")
    }

    @Test("candidate confirmation copy distinguishes a successful read from accepted data")
    func candidateConfirmationCopyIsExplicit() {
        let simplified = QuotaCopy(locale: .zhHans)
        let traditional = QuotaCopy(locale: .zhHant)
        let english = QuotaCopy(locale: .en)

        #expect(simplified.sourceStatusConfirming == "新数据确认中")
        #expect(traditional.sourceStatusConfirming == "新資料確認中")
        #expect(english.sourceStatusConfirming == "Confirming update")
        #expect(simplified.sourceConfirming(lastRefreshText: "10:00", lastAttemptText: "10:01").contains("继续显示 10:00"))
        #expect(simplified.sourceConfirmationPending("10:01").contains("读取成功，但新周期尚待确认"))
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
        #expect(!copy.sustainableLineTitle.contains("5%"))
        #expect(copy.forecastResetBandTitle.contains("重置余量"))
        #expect(copy.resetMarkerTitle == "重置")
        #expect(copy.resetTimeTitle == "周额度重置")
    }

    @Test("quota reset and data refresh use distinct, explicit time semantics")
    func timeSemanticsAreExplicit() throws {
        let copy = QuotaCopy(locale: .zhHans)
        let timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let now = try Date.ISO8601FormatStyle().parse("2026-07-13T05:50:13Z")
        let resetsAt = try Date.ISO8601FormatStyle().parse("2026-07-20T00:11:00Z")
        let lastSuccess = try Date.ISO8601FormatStyle().parse("2026-07-13T05:49:44Z")
        let nextAttempt = try Date.ISO8601FormatStyle().parse("2026-07-13T05:51:00Z")

        #expect(copy.quotaResetDescription(resetsAt: resetsAt, now: now, timeZone: timeZone) == "周额度将在 7月20日 08:11 重置（6天18小时后）")
        #expect(copy.dataRefreshDescription(lastSuccess: lastSuccess, nextAttempt: nextAttempt, now: now, timeZone: timeZone) == "数据更新于 13:49:44，下次自动读取约 47 秒后")
        #expect(!copy.quotaResetDescription(resetsAt: resetsAt, now: now, timeZone: timeZone).contains("刷新时间"))
    }

    @Test("the displayed next-24-hour budget rounds down")
    func budgetRoundsDown() {
        let model = CapsuleDisplayModel.make(forecast: forecast(budget: 13.9), locale: .zhHans)
        #expect(model.metrics[2].value == "≤13%")
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
        #expect(!model.showsLivePaceDetails)
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
