import Foundation

public enum QuotaPredictor {
    public static func predict(snapshot: AgentQuotaSnapshot, now: Date = Date()) -> CapsulePrediction {
        guard snapshot.sourceStatus == .ok else {
            return unknown("暂时读不到额度数据", snapshot.errorMessage ?? "Source status is not ok.")
        }

        guard let window = snapshot.shortWindow else {
            return unknown("缺少短窗口额度数据", "The source adapter did not provide a short usage window.")
        }

        return predict(window: window, now: now)
    }

    public static func predict(window: QuotaWindow, now: Date = Date()) -> CapsulePrediction {
        let windowStart = window.resetsAt.addingTimeInterval(TimeInterval(-window.windowMinutes * 60))
        let elapsedMinutes = now.timeIntervalSince(windowStart) / 60
        let minutesUntilReset = window.resetsAt.timeIntervalSince(now) / 60
        let elapsedPercent = clampPercent(Int(((elapsedMinutes / Double(window.windowMinutes)) * 100).rounded()))
        let usedPercent = clampPercent(window.usedPercent)

        if minutesUntilReset <= 0 {
            return unknown("额度刷新时间已过期", "The reset time is in the past. Refresh the source data.")
        }

        if window.remainingPercent <= 0 {
            return CapsulePrediction(
                level: .danger,
                canReachReset: false,
                elapsedPercent: elapsedPercent,
                quotaUsedPercent: usedPercent,
                projectedRemainingAtReset: 0,
                estimatedEmptyAt: now,
                headline: "额度已经见底",
                detail: "短窗口剩余额度为 0 或更低。"
            )
        }

        if elapsedMinutes <= 0 {
            return unknown("本地时间可能异常", "Current time appears to be before the usage window start.")
        }

        if elapsedMinutes < 3 {
            return CapsulePrediction(
                level: .unknown,
                canReachReset: nil,
                elapsedPercent: elapsedPercent,
                quotaUsedPercent: usedPercent,
                projectedRemainingAtReset: nil,
                estimatedEmptyAt: nil,
                headline: "刚刷新，先观察一会儿",
                detail: "窗口刚开始，当前消耗速度还不稳定。"
            )
        }

        if usedPercent <= 0 {
            return CapsulePrediction(
                level: .safe,
                canReachReset: true,
                elapsedPercent: elapsedPercent,
                quotaUsedPercent: 0,
                projectedRemainingAtReset: 100,
                estimatedEmptyAt: nil,
                headline: "还没开始消耗，能撑到 \(formatTime(window.resetsAt)) 刷新",
                detail: "当前窗口已用为 0。"
            )
        }

        let burnRatePerMinute = Double(usedPercent) / elapsedMinutes
        let projectedUsedAtReset = Double(usedPercent) + burnRatePerMinute * minutesUntilReset
        let projectedRemaining = 100 - projectedUsedAtReset

        if projectedRemaining <= 0 {
            let estimatedEmptyAt = now.addingTimeInterval((Double(window.remainingPercent) / burnRatePerMinute) * 60)
            return CapsulePrediction(
                level: .danger,
                canReachReset: false,
                elapsedPercent: elapsedPercent,
                quotaUsedPercent: usedPercent,
                projectedRemainingAtReset: 0,
                estimatedEmptyAt: estimatedEmptyAt,
                headline: "按当前速度，预计 \(formatTime(estimatedEmptyAt)) 用完",
                detail: "撑不到 \(formatTime(window.resetsAt)) 刷新。"
            )
        }

        let projectedRemainingPercent = clampPercent(Int(projectedRemaining.rounded()))
        let level: CapsuleLevel = projectedRemainingPercent < 10 ? .watch : .safe

        return CapsulePrediction(
            level: level,
            canReachReset: true,
            elapsedPercent: elapsedPercent,
            quotaUsedPercent: usedPercent,
            projectedRemainingAtReset: projectedRemainingPercent,
            estimatedEmptyAt: nil,
            headline: level == .watch
                ? "能撑到 \(formatTime(window.resetsAt))，但余量不多"
                : "按当前速度，够用到 \(formatTime(window.resetsAt)) 刷新",
            detail: "刷新时预计还剩 \(projectedRemainingPercent)% 。".replacingOccurrences(of: "% ", with: "%")
        )
    }

    private static func unknown(_ headline: String, _ detail: String) -> CapsulePrediction {
        CapsulePrediction(
            level: .unknown,
            canReachReset: nil,
            elapsedPercent: nil,
            quotaUsedPercent: nil,
            projectedRemainingAtReset: nil,
            estimatedEmptyAt: nil,
            headline: headline,
            detail: detail
        )
    }

    public static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func clampPercent(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}

