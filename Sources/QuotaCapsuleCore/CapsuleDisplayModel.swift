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
    public let metrics: [CapsuleMetric]

    public static func make(prediction: CapsulePrediction) -> CapsuleDisplayModel {
        CapsuleDisplayModel(
            tone: prediction.level,
            statusLabel: statusLabel(for: prediction.level),
            defaultText: compactText(for: prediction),
            metrics: [
                CapsuleMetric(label: "时间进度", value: formatPercent(prediction.elapsedPercent), numericValue: prediction.elapsedPercent),
                CapsuleMetric(label: "额度已用", value: formatPercent(prediction.quotaUsedPercent), numericValue: prediction.quotaUsedPercent),
                CapsuleMetric(label: "当前速度", value: formatBurnRate(prediction), numericValue: nil),
                CapsuleMetric(label: "刷新余量", value: formatPercent(prediction.projectedRemainingAtReset), numericValue: prediction.projectedRemainingAtReset)
            ]
        )
    }

    private static func statusLabel(for level: CapsuleLevel) -> String {
        switch level {
        case .safe: "安全"
        case .watch: "注意"
        case .danger: "危险"
        case .unknown: "未知"
        }
    }

    private static func compactText(for prediction: CapsulePrediction) -> String {
        if prediction.level == .unknown {
            return "暂时读不到额度"
        }
        if prediction.level == .danger, let estimatedEmptyAt = prediction.estimatedEmptyAt {
            return "预计 \(QuotaPredictor.formatTime(estimatedEmptyAt)) 见底"
        }
        if prediction.headline.contains("够用到") {
            return prediction.headline.replacingOccurrences(of: "按当前速度，", with: "")
        }
        if prediction.headline.contains("能撑到") {
            return prediction.headline.replacingOccurrences(of: "，但余量不多", with: "")
        }
        return prediction.headline
    }

    private static func formatPercent(_ value: Int?) -> String {
        guard let value else { return "未知" }
        return "\(value)%"
    }

    private static func formatBurnRate(_ prediction: CapsulePrediction) -> String {
        guard let elapsed = prediction.elapsedPercent,
              let used = prediction.quotaUsedPercent,
              elapsed > 0 else {
            return "未知"
        }
        return String(format: "%.2fx", Double(used) / Double(elapsed))
    }
}
