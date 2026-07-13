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

    public init(
        tone: CapsuleLevel,
        statusLabel: String,
        defaultText: String,
        compactDetail: String,
        metrics: [CapsuleMetric],
        confidenceText: String = "",
        freshnessText: String = ""
    ) {
        self.tone = tone
        self.statusLabel = statusLabel
        self.defaultText = defaultText
        self.compactDetail = compactDetail
        self.metrics = metrics
        self.confidenceText = confidenceText
        self.freshnessText = freshnessText
    }

    public static func make(prediction: CapsulePrediction, locale: QuotaLocale = .zhHans) -> CapsuleDisplayModel {
        let copy = QuotaCopy(locale: locale)
        let waiting = prediction.isWaitingForWindow
        return CapsuleDisplayModel(
            tone: prediction.level,
            statusLabel: waiting ? copy.statusWaiting : copy.statusLabel(for: prediction.level),
            defaultText: compactText(for: prediction, locale: locale),
            compactDetail: compactDetail(for: prediction),
            metrics: [
                CapsuleMetric(label: copy.metricElapsed, value: waiting ? copy.waitingValue : formatPercent(prediction.elapsedPercent, copy: copy), numericValue: prediction.elapsedPercent),
                CapsuleMetric(label: copy.metricUsed, value: waiting ? copy.waitingValue : formatUsedPercent(prediction, copy: copy), numericValue: prediction.quotaUsedPercent),
                CapsuleMetric(label: copy.metricPace, value: waiting ? copy.waitingValue : formatBurnRate(prediction, copy: copy), numericValue: nil),
                CapsuleMetric(label: copy.metricResetBuffer, value: waiting ? copy.waitingValue : formatPercent(prediction.projectedRemainingAtReset, copy: copy), numericValue: prediction.projectedRemainingAtReset)
            ]
        )
    }

    public static func make(
        forecast: WeeklyRunwayForecast,
        locale: QuotaLocale = .zhHans
    ) -> CapsuleDisplayModel {
        let copy = QuotaCopy(locale: locale)
        let labels = copy.weeklyMetricLabels
        let elapsed = safePercent(forecast.elapsedPercent)
        let used = safePercent(forecast.usedPercent)
        let recent = formatRateBand(forecast.recentRateBandPerDay, copy: copy, locale: locale)
        let budget = formatBudget(forecast.next24HourBudget, copy: copy)
        return CapsuleDisplayModel(
            tone: tone(for: forecast.state),
            statusLabel: copy.weeklyStatusLabel(forecast.state),
            defaultText: weeklyDefaultText(forecast, copy: copy, locale: locale),
            compactDetail: weeklyCompactDetail(forecast, locale: locale),
            metrics: [
                CapsuleMetric(label: labels[0], value: formatPercent(elapsed, copy: copy), numericValue: elapsed.map { Int($0.rounded()) }),
                CapsuleMetric(label: labels[1], value: formatPercent(used, copy: copy), numericValue: used.map { Int($0.rounded()) }),
                CapsuleMetric(label: labels[2], value: recent, numericValue: nil),
                CapsuleMetric(label: labels[3], value: budget, numericValue: nil)
            ],
            confidenceText: copy.forecastConfidence(forecast.confidence)
        )
    }

    private static func tone(for state: WeeklyRunwayState) -> CapsuleLevel {
        switch state {
        case .enough: .safe
        case .watch: .watch
        case .mayRunOut, .exhausted: .danger
        case .calibrating, .unavailable: .unknown
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
            case .zhHans: "本周额度已用尽，刷新后会自动恢复"
            case .zhHant: "本週額度已用盡，重設後會自動恢復"
            case .en: "This week's quota is exhausted and will recover at reset"
            }
        case .calibrating:
            switch locale {
            case .zhHans: "正在观察你的周速度，积累 6 小时有效数据后给出判断"
            case .zhHant: "正在觀察你的週速度，累積 6 小時有效資料後給出判斷"
            case .en: "Learning your weekly pace before making a runway judgment"
            }
        case .mayRunOut:
            switch locale {
            case .zhHans: "照最近速度，本周额度可能在刷新前用完"
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
        guard let range = safeProjectedRange(band) else {
            return switch locale {
            case .zhHans: "正在积累可靠的周速度预测"
            case .zhHant: "正在累積可靠的週速度預測"
            case .en: "Building a reliable weekly pace forecast"
            }
        }
        let lower = formatNumber(range.lower)
        let upper = formatNumber(range.upper)
        return switch locale {
        case .zhHans: "照最近速度，刷新时预计剩 \(lower)%–\(upper)%"
        case .zhHant: "照最近速度，重設時預計剩 \(lower)%–\(upper)%"
        case .en: "At the recent pace, \(lower)%–\(upper)% should remain at reset"
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

    private static func formatRateBand(
        _ band: PaceBand?,
        copy: QuotaCopy,
        locale: QuotaLocale
    ) -> String {
        guard let band,
              band.lower.isFinite,
              band.upper.isFinite,
              band.lower >= 0,
              band.upper >= band.lower else {
            return copy.accumulatingValue
        }
        let suffix = locale == .en ? "%/day" : "%/天"
        return "\(formatNumber(band.lower))–\(formatNumber(band.upper))\(suffix)"
    }

    private static func formatBudget(_ value: Double?, copy: QuotaCopy) -> String {
        guard let value, value.isFinite, value >= 0 else { return copy.accumulatingValue }
        return "≤\(formatNumber(min(100, value)))%"
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

    private static func compactText(for prediction: CapsulePrediction, locale: QuotaLocale) -> String {
        if prediction.isWaitingForWindow {
            return prediction.headline
        }
        if prediction.level == .unknown {
            return prediction.headline
        }
        if prediction.level == .danger, let estimatedEmptyAt = prediction.estimatedEmptyAt {
            let time = QuotaPredictor.formatTime(estimatedEmptyAt, locale: locale)
            switch locale {
            case .zhHans: return "预计 \(time) 见底"
            case .zhHant: return "預計 \(time) 見底"
            case .en: return "Runs out around \(time)"
            }
        }
        if locale == .zhHans, prediction.headline.contains("够用到") {
            return prediction.headline.replacingOccurrences(of: "按当前速度，", with: "")
        }
        if locale == .zhHans, prediction.headline.contains("能撑到") {
            return prediction.headline.replacingOccurrences(of: "，但余量不多", with: "")
        }
        if locale == .zhHant, prediction.headline.contains("可用到") {
            return prediction.headline.replacingOccurrences(of: "依目前速度，", with: "")
        }
        if locale == .zhHant, prediction.headline.contains("可撐到") {
            return prediction.headline.replacingOccurrences(of: "，但餘量不多", with: "")
        }
        if locale == .en {
            if prediction.headline.hasPrefix("Quota lasts until ") {
                return prediction.headline.replacingOccurrences(of: "Quota lasts until ", with: "Until ")
            }
            if prediction.headline.hasPrefix("Thin buffer until ") {
                return prediction.headline.replacingOccurrences(of: "Thin buffer until ", with: "Thin buffer to ")
            }
            if prediction.headline.hasPrefix("No usage yet; lasts until ") {
                return "No usage yet"
            }
        }
        return prediction.headline
    }

    private static func compactDetail(for prediction: CapsulePrediction) -> String {
        guard prediction.quotaUsedPercent != nil else {
            return ""
        }
        return formatUsedPercent(prediction, copy: QuotaCopy(locale: .en))
    }

    private static func formatPercent(_ value: Int?, copy: QuotaCopy) -> String {
        guard let value else { return copy.unknownValue }
        return "\(value)%"
    }

    private static func formatPercent(_ value: Double?, copy: QuotaCopy) -> String {
        guard let value else { return copy.unknownValue }
        return "\(formatNumber(value))%"
    }

    private static func formatUsedPercent(_ prediction: CapsulePrediction, copy: QuotaCopy) -> String {
        guard let value = prediction.quotaUsedPercentExact else { return copy.unknownValue }
        if value < 1 { return "<1%" }
        if value.rounded() == value { return "\(Int(value))%" }
        return String(format: "%.1f%%", value)
    }

    private static func formatBurnRate(_ prediction: CapsulePrediction, copy: QuotaCopy) -> String {
        guard let elapsed = prediction.elapsedPercent,
              let used = prediction.quotaUsedPercentExact,
              elapsed > 0 else {
            return copy.unknownValue
        }
        if used == 0 {
            let upperBound = max(0.01, 1 / Double(elapsed))
            return String(format: "<%.2fx", upperBound)
        }
        return String(format: "%.2fx", used / Double(elapsed))
    }
}
