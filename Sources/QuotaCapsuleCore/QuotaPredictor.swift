import Foundation

public enum QuotaPredictor {
    public static func predict(snapshot: AgentQuotaSnapshot, now: Date = Date(), locale: QuotaLocale = .zhHans) -> CapsulePrediction {
        let copy = QuotaCopy(locale: locale)

        guard snapshot.sourceStatus == .ok else {
            return unknown(sourceUnavailableHeadline(locale), snapshot.errorMessage ?? "Source status is not ok.")
        }

        if let exhaustedWindow = [snapshot.shortWindow, snapshot.weeklyWindow].compactMap({ $0 }).first(where: { window in
            window.remainingPercent <= 0 && window.resetsAt > now
        }) {
            return exhausted(window: exhaustedWindow, now: now, copy: copy)
        }

        guard let window = snapshot.shortWindow else {
            return unknown(missingShortWindowHeadline(locale), "The source adapter did not provide a short usage window.")
        }

        return predict(window: window, now: now, locale: locale)
    }

    public static func predict(window: QuotaWindow, now: Date = Date(), locale: QuotaLocale = .zhHans) -> CapsulePrediction {
        let copy = QuotaCopy(locale: locale)
        let windowStart = window.resetsAt.addingTimeInterval(TimeInterval(-window.windowMinutes * 60))
        let elapsedMinutes = now.timeIntervalSince(windowStart) / 60
        let minutesUntilReset = window.resetsAt.timeIntervalSince(now) / 60
        let elapsedPercent = clampPercent(Int(((elapsedMinutes / Double(window.windowMinutes)) * 100).rounded()))
        let usedPercent = clampPercent(window.usedPercent)

        if minutesUntilReset <= 0 {
            return unknown(expiredResetHeadline(locale), "The reset time is in the past. Refresh the source data.")
        }

        if window.remainingPercent <= 0 {
            return exhausted(window: window, now: now, copy: copy)
        }

        if elapsedMinutes <= 0 {
            return unknown(localTimeAbnormalHeadline(locale), "Current time appears to be before the usage window start.")
        }

        if elapsedMinutes < 3 {
            return CapsulePrediction(
                level: .unknown,
                canReachReset: nil,
                elapsedPercent: elapsedPercent,
                quotaUsedPercent: usedPercent,
                projectedRemainingAtReset: nil,
                estimatedEmptyAt: nil,
                headline: justResetHeadline(locale),
                detail: justResetDetail(locale)
            )
        }

        if usedPercent <= 0 {
            let resetText = formatTime(window.resetsAt, locale: locale)
            return CapsulePrediction(
                level: .safe,
                canReachReset: true,
                elapsedPercent: elapsedPercent,
                quotaUsedPercent: 0,
                projectedRemainingAtReset: 100,
                estimatedEmptyAt: nil,
                headline: noUsageHeadline(resetText, locale),
                detail: noUsageDetail(locale)
            )
        }

        let burnRatePerMinute = Double(usedPercent) / elapsedMinutes
        let projectedUsedAtReset = Double(usedPercent) + burnRatePerMinute * minutesUntilReset
        let projectedRemaining = 100 - projectedUsedAtReset

        if projectedRemaining <= 0 {
            let estimatedEmptyAt = now.addingTimeInterval((Double(window.remainingPercent) / burnRatePerMinute) * 60)
            let emptyText = formatTime(estimatedEmptyAt, locale: locale)
            let resetText = formatTime(window.resetsAt, locale: locale)
            return CapsulePrediction(
                level: .danger,
                canReachReset: false,
                elapsedPercent: elapsedPercent,
                quotaUsedPercent: usedPercent,
                projectedRemainingAtReset: 0,
                estimatedEmptyAt: estimatedEmptyAt,
                headline: projectedExhaustionHeadline(emptyText, locale),
                detail: cannotReachResetDetail(resetText, locale)
            )
        }

        let projectedRemainingPercent = clampPercent(Int(projectedRemaining.rounded()))
        let level: CapsuleLevel = projectedRemainingPercent < 10 ? .watch : .safe
        let resetText = formatTime(window.resetsAt, locale: locale)

        return CapsulePrediction(
            level: level,
            canReachReset: true,
            elapsedPercent: elapsedPercent,
            quotaUsedPercent: usedPercent,
            projectedRemainingAtReset: projectedRemainingPercent,
            estimatedEmptyAt: nil,
            headline: level == .watch
                ? lowBufferHeadline(resetText, locale)
                : safeRunwayHeadline(resetText, locale),
            detail: projectedRemainingDetail(projectedRemainingPercent, locale)
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

    private static func exhausted(window: QuotaWindow, now: Date, copy: QuotaCopy) -> CapsulePrediction {
        let windowStart = window.resetsAt.addingTimeInterval(TimeInterval(-window.windowMinutes * 60))
        let elapsedMinutes = now.timeIntervalSince(windowStart) / 60
        let elapsedPercent = clampPercent(Int(((elapsedMinutes / Double(window.windowMinutes)) * 100).rounded()))
        let usedPercent = clampPercent(window.usedPercent)

        return CapsulePrediction(
            level: .danger,
            canReachReset: false,
            elapsedPercent: elapsedPercent,
            quotaUsedPercent: usedPercent,
            projectedRemainingAtReset: 0,
            estimatedEmptyAt: now,
            headline: exhaustedHeadline(copy.locale),
            detail: exhaustedDetail(window.label, copy.locale)
        )
    }

    public static func formatTime(_ date: Date) -> String {
        formatTime(date, locale: .zhHans)
    }

    public static func formatTime(_ date: Date, locale: QuotaLocale) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: dateLocaleIdentifier(locale))
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func clampPercent(_ value: Int) -> Int {
        min(100, max(0, value))
    }

    private static func dateLocaleIdentifier(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "zh_CN"
        case .zhHant: "zh_TW"
        case .en: "en_US_POSIX"
        }
    }

    private static func sourceUnavailableHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "暂时读不到额度数据"
        case .zhHant: "暫時讀不到額度資料"
        case .en: "Quota data is unavailable"
        }
    }

    private static func missingShortWindowHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "缺少短窗口额度数据"
        case .zhHant: "缺少短週期額度資料"
        case .en: "Short quota window is missing"
        }
    }

    private static func expiredResetHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "额度刷新时间已过期"
        case .zhHant: "額度重設時間已過期"
        case .en: "Quota reset time is stale"
        }
    }

    private static func localTimeAbnormalHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "本地时间可能异常"
        case .zhHant: "本機時間可能異常"
        case .en: "Local time may be incorrect"
        }
    }

    private static func justResetHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "刚刷新，先观察一会儿"
        case .zhHant: "剛重設，先觀察一下"
        case .en: "Just reset; watching usage"
        }
    }

    private static func justResetDetail(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "窗口刚开始，当前消耗速度还不稳定。"
        case .zhHant: "週期剛開始，目前消耗速度還不穩定。"
        case .en: "The window just started, so the current burn rate is not stable yet."
        }
    }

    private static func noUsageHeadline(_ resetText: String, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "还没开始消耗，能撑到 \(resetText) 刷新"
        case .zhHant: "尚未開始消耗，可撐到 \(resetText) 重設"
        case .en: "No usage yet; should last until \(resetText)"
        }
    }

    private static func noUsageDetail(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "当前窗口已用为 0。"
        case .zhHant: "目前週期已用為 0。"
        case .en: "Current window usage is 0."
        }
    }

    private static func projectedExhaustionHeadline(_ emptyText: String, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "按当前速度，预计 \(emptyText) 用完"
        case .zhHant: "依目前速度，預計 \(emptyText) 用完"
        case .en: "At this pace, quota runs out around \(emptyText)"
        }
    }

    private static func cannotReachResetDetail(_ resetText: String, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "撑不到 \(resetText) 刷新。"
        case .zhHant: "撐不到 \(resetText) 重設。"
        case .en: "It will not last until the \(resetText) reset."
        }
    }

    private static func lowBufferHeadline(_ resetText: String, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "能撑到 \(resetText)，但余量不多"
        case .zhHant: "可撐到 \(resetText)，但餘量不多"
        case .en: "Can last until \(resetText), but buffer is thin"
        }
    }

    private static func safeRunwayHeadline(_ resetText: String, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "按当前速度，够用到 \(resetText) 刷新"
        case .zhHant: "依目前速度，可用到 \(resetText) 重設"
        case .en: "At this pace, quota lasts until \(resetText)"
        }
    }

    private static func projectedRemainingDetail(_ percent: Int, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "刷新时预计还剩 \(percent)% 。".replacingOccurrences(of: "% ", with: "%")
        case .zhHant: "重設時預計還剩 \(percent)% 。".replacingOccurrences(of: "% ", with: "%")
        case .en: "Projected remaining at reset: \(percent)%."
        }
    }

    private static func exhaustedHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "额度已经见底"
        case .zhHant: "額度已經見底"
        case .en: "Quota is exhausted"
        }
    }

    private static func exhaustedDetail(_ windowLabel: String, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "\(windowLabel) 窗口剩余额度为 0 或更低。"
        case .zhHant: "\(windowLabel) 週期剩餘額度為 0 或更低。"
        case .en: "\(windowLabel) window remaining quota is 0 or lower."
        }
    }
}
