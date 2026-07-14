import Foundation

public struct CapsuleMetric: Equatable, Sendable {
    public let label: String
    public let value: String
    public let numericValue: Int?
}

public struct CapsuleDisplayModel: Equatable, Sendable {
    public let tone: CapsuleLevel
    public let statusLabel: String
    public let defaultText: String
    public let compactDetail: String
    public let metrics: [CapsuleMetric]
    public let confidenceText: String
    public let freshnessText: String
    public let showsLivePaceDetails: Bool

    public init(
        tone: CapsuleLevel,
        statusLabel: String,
        defaultText: String,
        compactDetail: String,
        metrics: [CapsuleMetric],
        confidenceText: String = "",
        freshnessText: String = "",
        showsLivePaceDetails: Bool = false
    ) {
        self.tone = tone
        self.statusLabel = statusLabel
        self.defaultText = defaultText
        self.compactDetail = compactDetail
        self.metrics = metrics
        self.confidenceText = confidenceText
        self.freshnessText = freshnessText
        self.showsLivePaceDetails = showsLivePaceDetails
    }

    public static func make(
        forecast: WeeklyRunwayForecast,
        locale: QuotaLocale = .zhHans
    ) -> CapsuleDisplayModel {
        let copy = QuotaCopy(locale: locale)
        let labels = copy.weeklyMetricLabels
        let elapsed = safePercent(forecast.elapsedPercent)
        let used = safePercent(forecast.usedPercent)
        let budget = formatBudget(forecast.next24HourBudget, copy: copy)
        let recent = formatUsageBand(forecast.last24HourUsageBand, copy: copy)
        return CapsuleDisplayModel(
            tone: tone(for: forecast.state),
            statusLabel: copy.weeklyStatusLabel(forecast.state),
            defaultText: weeklyDefaultText(forecast, copy: copy, locale: locale),
            compactDetail: weeklyCompactDetail(forecast, locale: locale),
            metrics: [
                CapsuleMetric(label: labels[0], value: formatPercent(elapsed, copy: copy), numericValue: elapsed.map { Int($0.rounded()) }),
                CapsuleMetric(label: labels[1], value: formatPercent(used, copy: copy), numericValue: used.map { Int($0.rounded()) }),
                CapsuleMetric(label: labels[2], value: budget, numericValue: nil),
                CapsuleMetric(label: labels[3], value: recent, numericValue: nil)
            ],
            confidenceText: copy.confidenceReason(forecast),
            showsLivePaceDetails: forecast.state != .unavailable
                && forecast.state != .calibrating
                && forecast.confidenceReason != "no-consumption-observed"
        )
    }

    public static func makeStale(
        lastSuccessfulForecast: WeeklyRunwayForecast,
        locale: QuotaLocale = .zhHans
    ) -> CapsuleDisplayModel {
        let copy = QuotaCopy(locale: locale)
        let labels = copy.weeklyMetricLabels
        let elapsed = safePercent(lastSuccessfulForecast.elapsedPercent)
        let used = safePercent(lastSuccessfulForecast.usedPercent)
        let suppressedValue: String
        let detail: String
        switch locale {
        case .zhHans:
            suppressedValue = "暂不判断"
            detail = "正在显示上次成功的周额度数据，恢复实时读取前暂不判断周速度。"
        case .zhHant:
            suppressedValue = "暫不判斷"
            detail = "正在顯示上次成功的週額度資料，恢復即時讀取前暫不判斷週速度。"
        case .en:
            suppressedValue = "Not judged"
            detail = "Showing the last successful weekly reading. Pace judgment is paused until live reads recover."
        }
        return CapsuleDisplayModel(
            tone: .unknown,
            statusLabel: copy.statusStale,
            defaultText: detail,
            compactDetail: weeklyCompactDetail(lastSuccessfulForecast, locale: locale),
            metrics: [
                CapsuleMetric(label: labels[0], value: formatPercent(elapsed, copy: copy), numericValue: elapsed.map { Int($0.rounded()) }),
                CapsuleMetric(label: labels[1], value: formatPercent(used, copy: copy), numericValue: used.map { Int($0.rounded()) }),
                CapsuleMetric(label: labels[2], value: suppressedValue, numericValue: nil),
                CapsuleMetric(label: labels[3], value: suppressedValue, numericValue: nil)
            ],
            showsLivePaceDetails: false
        )
    }

    public var usedQuotaText: String? {
        guard metrics.indices.contains(1) else { return nil }
        return metrics[1].value
    }

    private static func tone(for state: WeeklyRunwayState) -> CapsuleLevel {
        switch state {
        case .enough: .safe
        case .watch: .watch
        case .mayRunOut, .exhausted: .danger
        case .calibrating, .earlyEstimate, .unavailable: .unknown
        }
    }

    private static func weeklyDefaultText(
        _ forecast: WeeklyRunwayForecast,
        copy: QuotaCopy,
        locale: QuotaLocale
    ) -> String {
        return switch forecast.state {
        case .unavailable:
            switch locale {
            case .zhHans: "暂时没有可用的周额度数据"
            case .zhHant: "暫時沒有可用的週額度資料"
            case .en: "Weekly quota data is temporarily unavailable"
            }
        case .exhausted:
            switch locale {
            case .zhHans: "本周额度已用尽，重置后会自动恢复"
            case .zhHant: "本週額度已用盡，重設後會自動恢復"
            case .en: "This week's quota is exhausted and will recover at reset"
            }
        case .calibrating:
            switch locale {
            case .zhHans: "数据正在确认，本次暂不更新周速度判断"
            case .zhHant: "資料正在確認，本次暫不更新週速度判斷"
            case .en: "Data is being confirmed; the pace judgment is unchanged for now"
            }
        case .earlyEstimate:
            if forecast.confidenceReason == "no-consumption-observed" {
                switch locale {
                case .zhHans: "尚未观察到消耗；可先按未来 24 小时建议使用"
                case .zhHant: "尚未觀察到消耗；可先按未來 24 小時建議使用"
                case .en: "No usage observed yet; start with the next 24-hour budget"
                }
            } else {
                earlyEstimateText(forecast.projectedRemainingBandAtReset, locale: locale)
            }
        case .mayRunOut:
            switch locale {
            case .zhHans: "照最近速度，本周额度可能在重置前用完"
            case .zhHant: "照最近速度，本週額度可能在重設前用完"
            case .en: "At the recent pace, weekly quota may run out before reset"
            }
        case .enough, .watch:
            weeklyProjectionText(forecast.projectedRemainingBandAtReset, locale: locale)
        }
    }

    private static func weeklyProjectionText(
        _ band: PercentageBand?,
        locale: QuotaLocale
    ) -> String {
        guard let band, band.lower.isFinite, band.upper.isFinite else {
            return switch locale {
            case .zhHans: "正在积累可靠的周速度预测"
            case .zhHant: "正在累積可靠的週速度預測"
            case .en: "Building a reliable weekly pace forecast"
            }
        }
        let lower = min(band.lower, band.upper)
        let upper = max(band.lower, band.upper)
        if upper < 0 {
            return switch locale {
            case .zhHans: "照最近速度，本周额度可能在重置前用完"
            case .zhHant: "照最近速度，本週額度可能在重設前用完"
            case .en: "At the recent pace, weekly quota may run out before reset"
            }
        }
        if lower < 0 {
            let maximum = Int(upper.rounded())
            return switch locale {
            case .zhHans: "按较快节奏可能提前用完；较慢情景重置时最多剩 \(maximum)%"
            case .zhHant: "按較快節奏可能提前用完；較慢情境重設時最多剩 \(maximum)%"
            case .en: "The faster scenario may run out early; the slower scenario leaves at most \(maximum)% at reset"
            }
        }
        let roundedLower = Int(lower.rounded())
        let roundedUpper = Int(upper.rounded())
        return switch locale {
        case .zhHans: "照最近速度，重置时预计剩 \(roundedLower)%–\(roundedUpper)%"
        case .zhHant: "照最近速度，重設時預計剩 \(roundedLower)%–\(roundedUpper)%"
        case .en: "At the recent pace, \(roundedLower)%–\(roundedUpper)% should remain at reset"
        }
    }

    private static func earlyEstimateText(
        _ band: PercentageBand?,
        locale: QuotaLocale
    ) -> String {
        let outcome: Int
        if let band, band.lower.isFinite, band.upper.isFinite {
            outcome = band.upper < 0 ? 2 : band.lower <= 0 ? 1 : 0
        } else {
            outcome = 1
        }
        return switch (locale, outcome) {
        case (.zhHans, 0): "初步判断：按本周平均速度目前可持续"
        case (.zhHans, 1): "初步判断：按本周平均速度可能偏快"
        case (.zhHans, _): "初步判断：按本周平均速度可能不够"
        case (.zhHant, 0): "初步判斷：按本週平均速度目前可持續"
        case (.zhHant, 1): "初步判斷：按本週平均速度可能偏快"
        case (.zhHant, _): "初步判斷：按本週平均速度可能不夠"
        case (.en, 0): "Early estimate: the current-cycle average looks sustainable"
        case (.en, 1): "Early estimate: the current-cycle average may be running fast"
        case (.en, _): "Early estimate: the current-cycle average may not last"
        }
    }

    private static func weeklyCompactDetail(
        _ forecast: WeeklyRunwayForecast,
        locale: QuotaLocale
    ) -> String {
        guard let used = safePercent(forecast.usedPercent) else { return "" }
        return switch locale {
        case .zhHans: "本周已用 \(formatNumber(used))%"
        case .zhHant: "本週已用 \(formatNumber(used))%"
        case .en: "\(formatNumber(used))% used this week"
        }
    }

    private static func formatUsageBand(_ band: PercentageBand?, copy: QuotaCopy) -> String {
        guard let band = safeProjectedRange(band) else { return copy.accumulatingValue }
        return "\(formatNumber(band.lower))–\(formatNumber(band.upper))%"
    }

    private static func formatBudget(_ value: Double?, copy: QuotaCopy) -> String {
        guard let value, value.isFinite, value >= 0 else { return copy.accumulatingValue }
        return "≤\(Int(floor(min(100, value))))%"
    }

    private static func safePercent(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(100, max(0, value))
    }

    private static func safeProjectedRange(_ band: PercentageBand?) -> PercentageBand? {
        guard let band, band.lower.isFinite, band.upper.isFinite else { return nil }
        let lower = min(100, max(0, band.lower))
        let upper = min(100, max(0, band.upper))
        return PercentageBand(lower: min(lower, upper), upper: max(lower, upper))
    }

    private static func formatNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    private static func formatPercent(_ value: Double?, copy: QuotaCopy) -> String {
        guard let value else { return copy.unknownValue }
        return "\(formatNumber(value))%"
    }

}
