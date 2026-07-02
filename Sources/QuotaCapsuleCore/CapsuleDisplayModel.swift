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
        return CapsuleDisplayModel(
            tone: prediction.level,
            statusLabel: copy.statusLabel(for: prediction.level),
            defaultText: compactText(for: prediction, locale: locale),
            compactDetail: compactDetail(for: prediction),
            metrics: [
                CapsuleMetric(label: copy.metricElapsed, value: formatPercent(prediction.elapsedPercent, copy: copy), numericValue: prediction.elapsedPercent),
                CapsuleMetric(label: copy.metricUsed, value: formatPercent(prediction.quotaUsedPercent, copy: copy), numericValue: prediction.quotaUsedPercent),
                CapsuleMetric(label: copy.metricPace, value: formatBurnRate(prediction, copy: copy), numericValue: nil),
                CapsuleMetric(label: copy.metricResetBuffer, value: formatPercent(prediction.projectedRemainingAtReset, copy: copy), numericValue: prediction.projectedRemainingAtReset)
            ]
        )
    }

    private static func compactText(for prediction: CapsulePrediction, locale: QuotaLocale) -> String {
        if prediction.level == .unknown {
            switch locale {
            case .zhHans: return "暂时读不到额度"
            case .zhHant: return "暫時讀不到額度"
            case .en: return "Quota unavailable"
            }
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
        guard let usedPercent = prediction.quotaUsedPercent else {
            return ""
        }
        return "\(usedPercent)%"
    }

    private static func formatPercent(_ value: Int?, copy: QuotaCopy) -> String {
        guard let value else { return copy.unknownValue }
        return "\(value)%"
    }

    private static func formatBurnRate(_ prediction: CapsulePrediction, copy: QuotaCopy) -> String {
        guard let elapsed = prediction.elapsedPercent,
              let used = prediction.quotaUsedPercent,
              elapsed > 0 else {
            return copy.unknownValue
        }
        return String(format: "%.2fx", Double(used) / Double(elapsed))
    }
}
