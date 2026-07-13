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
