import Foundation

public enum QuotaPredictor {
    private static let weeklyForecastEarlyWatchUsedPercent = 5
    private static let weeklyForecastMinimumElapsedPercent = 5.0
    private static let clockSkewToleranceSeconds = 2.0
    private static let reportingPrecisionUpperBound = 1.0

    public static func predict(snapshot: AgentQuotaSnapshot, now: Date = Date(), locale: QuotaLocale = .zhHans) -> CapsulePrediction {
        let copy = QuotaCopy(locale: locale)

        if snapshot.sourceStatus == .stale {
            return stale(snapshot: snapshot, locale: locale)
        }

        guard snapshot.sourceStatus == .ok else {
            return unknown(sourceUnavailableHeadline(locale), snapshot.errorMessage ?? sourceUnavailableDetail(locale))
        }

        if let exhaustedWindow = [snapshot.shortWindow, snapshot.weeklyWindow].compactMap({ $0 }).first(where: { window in
            isValid(window) && window.remainingPercent <= 0 && window.resetsAt > now
        }) {
            return exhausted(window: exhaustedWindow, now: now, copy: copy)
        }

        guard let window = snapshot.shortWindow else {
            return waitingForShortWindow(locale)
        }

        return predict(window: window, now: now, locale: locale)
    }

    public static func predictWeekly(snapshot: AgentQuotaSnapshot, now: Date = Date(), locale: QuotaLocale = .zhHans) -> CapsulePrediction? {
        guard snapshot.sourceStatus == .ok, let weeklyWindow = snapshot.weeklyWindow else {
            return nil
        }
        return predictWeekly(window: weeklyWindow, now: now, locale: locale)
    }

    public static func predictWeekly(window: QuotaWindow, now: Date = Date(), locale: QuotaLocale = .zhHans) -> CapsulePrediction {
        guard isValid(window) else {
            return unknown(invalidWindowHeadline(locale), invalidWindowDetail(locale))
        }
        let windowStart = window.resetsAt.addingTimeInterval(TimeInterval(-window.windowMinutes * 60))
        let elapsedMinutes = now.timeIntervalSince(windowStart) / 60
        let minutesUntilReset = window.resetsAt.timeIntervalSince(now) / 60
        let elapsedPercentExact = (elapsedMinutes / Double(window.windowMinutes)) * 100
        let elapsedPercent = clampPercent(Int(elapsedPercentExact.rounded()))
        let usedPercent = displayPercent(window.usedPercent)

        if minutesUntilReset > 0,
           elapsedMinutes > 0,
           window.remainingPercent > 0,
           window.usedPercent > 0,
           elapsedPercentExact < weeklyForecastMinimumElapsedPercent {
            let level: CapsuleLevel = usedPercent >= weeklyForecastEarlyWatchUsedPercent ? .watch : .unknown
            return CapsulePrediction(
                level: level,
                canReachReset: nil,
                elapsedPercent: elapsedPercent,
                quotaUsedPercent: usedPercent,
                quotaUsedPercentExact: window.usedPercent,
                projectedRemainingAtReset: nil,
                estimatedEmptyAt: nil,
                headline: weeklyWarmupHeadline(usedPercent: usedPercent, locale),
                detail: justResetDetail(locale)
            )
        }

        return predict(window: window, now: now, locale: locale)
    }

    public static func predict(window: QuotaWindow, now: Date = Date(), locale: QuotaLocale = .zhHans) -> CapsulePrediction {
        guard isValid(window) else {
            return unknown(invalidWindowHeadline(locale), invalidWindowDetail(locale))
        }
        let copy = QuotaCopy(locale: locale)
        let windowStart = window.resetsAt.addingTimeInterval(TimeInterval(-window.windowMinutes * 60))
        let elapsedMinutes = now.timeIntervalSince(windowStart) / 60
        let minutesUntilReset = window.resetsAt.timeIntervalSince(now) / 60
        let elapsedPercent = clampPercent(Int(((elapsedMinutes / Double(window.windowMinutes)) * 100).rounded()))
        let usedExact = clampUsage(window.usedPercent)
        let usedPercent = displayPercent(usedExact)

        if minutesUntilReset <= 0 {
            return unknown(expiredResetHeadline(locale), expiredResetDetail(locale))
        }

        if window.remainingPercent <= 0 {
            return exhausted(window: window, now: now, copy: copy)
        }

        if elapsedMinutes < -(clockSkewToleranceSeconds / 60) {
            return unknown(localTimeAbnormalHeadline(locale), localTimeAbnormalDetail(locale))
        }

        let effectiveElapsedMinutes = max(0, elapsedMinutes)

        if usedExact <= 0 {
            if effectiveElapsedMinutes <= 3 {
                return CapsulePrediction(
                    level: .unknown,
                    canReachReset: nil,
                    elapsedPercent: elapsedPercent,
                    quotaUsedPercent: 0,
                    quotaUsedPercentExact: 0,
                    projectedRemainingAtReset: nil,
                    estimatedEmptyAt: nil,
                    headline: belowPrecisionWarmupHeadline(locale),
                    detail: belowPrecisionDetail(locale)
                )
            }

            let projectedUsedUpperBound = (reportingPrecisionUpperBound / effectiveElapsedMinutes) * Double(window.windowMinutes)
            guard projectedUsedUpperBound < 100 else {
                return CapsulePrediction(
                    level: .unknown,
                    canReachReset: nil,
                    elapsedPercent: elapsedPercent,
                    quotaUsedPercent: 0,
                    quotaUsedPercentExact: 0,
                    projectedRemainingAtReset: nil,
                    estimatedEmptyAt: nil,
                    headline: belowPrecisionWarmupHeadline(locale),
                    detail: belowPrecisionDetail(locale)
                )
            }

            let projectedRemainingPercent = clampPercent(Int(floor(100 - projectedUsedUpperBound)))
            let level: CapsuleLevel = projectedRemainingPercent < 10 ? .watch : .safe
            let resetText = formatTime(window.resetsAt, locale: locale)
            return CapsulePrediction(
                level: level,
                canReachReset: true,
                elapsedPercent: elapsedPercent,
                quotaUsedPercent: 0,
                quotaUsedPercentExact: 0,
                projectedRemainingAtReset: projectedRemainingPercent,
                estimatedEmptyAt: nil,
                headline: belowPrecisionSafeHeadline(resetText, locale),
                detail: belowPrecisionProjectionDetail(projectedRemainingPercent, locale)
            )
        }

        if effectiveElapsedMinutes < 3 {
            return CapsulePrediction(
                level: .unknown,
                canReachReset: nil,
                elapsedPercent: elapsedPercent,
                quotaUsedPercent: usedPercent,
                quotaUsedPercentExact: usedExact,
                projectedRemainingAtReset: nil,
                estimatedEmptyAt: nil,
                headline: justResetHeadline(locale),
                detail: justResetDetail(locale)
            )
        }

        let burnRatePerMinute = usedExact / effectiveElapsedMinutes
        let projectedUsedAtReset = usedExact + burnRatePerMinute * minutesUntilReset
        let projectedRemaining = 100 - projectedUsedAtReset

        if projectedRemaining <= 0 {
            let estimatedEmptyAt = now.addingTimeInterval((window.remainingPercent / burnRatePerMinute) * 60)
            let emptyText = formatTime(estimatedEmptyAt, locale: locale)
            let resetText = formatTime(window.resetsAt, locale: locale)
            return CapsulePrediction(
                level: .danger,
                canReachReset: false,
                elapsedPercent: elapsedPercent,
                quotaUsedPercent: usedPercent,
                quotaUsedPercentExact: usedExact,
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
            quotaUsedPercentExact: usedExact,
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

    private static func waitingForShortWindow(_ locale: QuotaLocale) -> CapsulePrediction {
        CapsulePrediction(
            level: .unknown,
            canReachReset: nil,
            elapsedPercent: nil,
            quotaUsedPercent: nil,
            projectedRemainingAtReset: nil,
            estimatedEmptyAt: nil,
            isWaitingForWindow: true,
            headline: waitingForShortWindowHeadline(locale),
            detail: waitingForShortWindowDetail(locale)
        )
    }

    private static func stale(snapshot: AgentQuotaSnapshot, locale: QuotaLocale) -> CapsulePrediction {
        guard let window = snapshot.shortWindow, isValid(window) else {
            return unknown(staleHeadline(locale), staleDetail(snapshot.fetchedAt, locale: locale))
        }

        let windowStart = window.resetsAt.addingTimeInterval(TimeInterval(-window.windowMinutes * 60))
        let elapsedMinutes = snapshot.fetchedAt.timeIntervalSince(windowStart) / 60
        let elapsedPercent = clampPercent(Int(((max(0, elapsedMinutes) / Double(window.windowMinutes)) * 100).rounded()))

        return CapsulePrediction(
            level: .unknown,
            canReachReset: nil,
            elapsedPercent: elapsedPercent,
            quotaUsedPercent: displayPercent(window.usedPercent),
            quotaUsedPercentExact: window.usedPercent,
            projectedRemainingAtReset: nil,
            estimatedEmptyAt: nil,
            headline: staleHeadline(locale),
            detail: staleDetail(snapshot.fetchedAt, locale: locale)
        )
    }

    private static func exhausted(window: QuotaWindow, now: Date, copy: QuotaCopy) -> CapsulePrediction {
        let windowStart = window.resetsAt.addingTimeInterval(TimeInterval(-window.windowMinutes * 60))
        let elapsedMinutes = now.timeIntervalSince(windowStart) / 60
        let elapsedPercent = clampPercent(Int(((elapsedMinutes / Double(window.windowMinutes)) * 100).rounded()))
        let usedPercent = displayPercent(window.usedPercent)

        return CapsulePrediction(
            level: .danger,
            canReachReset: false,
            elapsedPercent: elapsedPercent,
            quotaUsedPercent: usedPercent,
            quotaUsedPercentExact: window.usedPercent,
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

    private static func clampUsage(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    private static func displayPercent(_ value: Double) -> Int {
        clampPercent(Int(floor(clampUsage(value))))
    }

    private static func isValid(_ window: QuotaWindow) -> Bool {
        window.windowMinutes > 0
            && window.windowMinutes <= 525_600
            && window.usedPercent.isFinite
            && (0...100).contains(window.usedPercent)
            && window.remainingPercent.isFinite
            && (0...100).contains(window.remainingPercent)
            && window.resetsAt.timeIntervalSince1970.isFinite
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

    private static func waitingForShortWindowHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "等待新的 5 小时窗口"
        case .zhHant: "等待新的 5 小時週期"
        case .en: "Waiting for the next 5-hour window"
        }
    }

    private static func sourceUnavailableDetail(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "数据源当前没有返回可用额度。"
        case .zhHant: "資料來源目前沒有返回可用額度。"
        case .en: "The source did not return usable quota data."
        }
    }

    private static func waitingForShortWindowDetail(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "当前没有活动中的 5 小时窗口。开始使用 Codex 后会自动显示进度；如果你已经开始使用，应用会继续自动刷新。"
        case .zhHant: "目前沒有進行中的 5 小時週期。開始使用 Codex 後會自動顯示進度；如果你已經開始使用，App 會繼續自動重新整理。"
        case .en: "There is no active 5-hour window. It appears automatically after you start using Codex; if you already started, the app will keep refreshing."
        }
    }

    private static func invalidWindowHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "额度窗口数据无效"
        case .zhHant: "額度週期資料無效"
        case .en: "Quota window data is invalid"
        }
    }

    private static func invalidWindowDetail(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "窗口时长或百分比超出安全范围。"
        case .zhHant: "週期時長或百分比超出安全範圍。"
        case .en: "The window duration or percentage is outside the safe range."
        }
    }

    private static func expiredResetHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "额度刷新时间已过期"
        case .zhHant: "額度重設時間已過期"
        case .en: "Quota reset time is stale"
        }
    }

    private static func expiredResetDetail(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "刷新时间已经过去，请重新读取额度。"
        case .zhHant: "重設時間已經過去，請重新讀取額度。"
        case .en: "The reset time is in the past. Refresh quota data."
        }
    }

    private static func localTimeAbnormalHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "本地时间可能异常"
        case .zhHant: "本機時間可能異常"
        case .en: "Local time may be incorrect"
        }
    }

    private static func localTimeAbnormalDetail(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "当前时间早于额度窗口开始时间。"
        case .zhHant: "目前時間早於額度週期開始時間。"
        case .en: "Current time is before the quota window start."
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

    private static func weeklyWarmupHeadline(usedPercent: Int, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "本周刚开始，已用 \(usedPercent)%，先观察趋势"
        case .zhHant: "本週剛開始，已用 \(usedPercent)%，先觀察趨勢"
        case .en: "Week just started; \(usedPercent)% used so far"
        }
    }

    private static func belowPrecisionWarmupHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "当前读数低于 1%，先观察一会儿"
        case .zhHant: "目前讀數低於 1%，先觀察一下"
        case .en: "Usage is below 1%; watching"
        }
    }

    private static func belowPrecisionSafeHeadline(_ resetText: String, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "当前读数低于 1%，保守估计够用到 \(resetText)"
        case .zhHant: "目前讀數低於 1%，保守估計可用到 \(resetText)"
        case .en: "Below 1%; conservative estimate lasts until \(resetText)"
        }
    }

    private static func belowPrecisionDetail(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "Codex 的百分比读数不足以证明没有使用，暂不判断消耗速度。"
        case .zhHant: "Codex 的百分比讀數不足以證明沒有使用，暫不判斷消耗速度。"
        case .en: "The percentage reading cannot prove there was no usage, so no burn-rate conclusion is shown yet."
        }
    }

    private static func belowPrecisionProjectionDetail(_ percent: Int, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "按低于 1% 的上限估算，刷新时至少剩 \(percent)% 。".replacingOccurrences(of: "% ", with: "%")
        case .zhHant: "按低於 1% 的上限估算，重設時至少剩 \(percent)% 。".replacingOccurrences(of: "% ", with: "%")
        case .en: "Using the under-1% upper bound, at least \(percent)% should remain at reset."
        }
    }

    private static func staleHeadline(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "数据已过期，等待恢复"
        case .zhHant: "資料已過期，等待恢復"
        case .en: "Data is stale; waiting to recover"
        }
    }

    private static func staleDetail(_ fetchedAt: Date, locale: QuotaLocale) -> String {
        let time = formatTime(fetchedAt, locale: locale)
        return switch locale {
        case .zhHans: "正在显示 \(time) 的最后成功读数，不能据此判断当前风险。"
        case .zhHant: "正在顯示 \(time) 的最後成功讀數，不能據此判斷目前風險。"
        case .en: "Showing the last successful reading from \(time); it cannot determine current risk."
        }
    }

    private static func projectedExhaustionHeadline(_ emptyText: String, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "按当前速度，预计 \(emptyText) 用完"
        case .zhHant: "依目前速度，預計 \(emptyText) 用完"
        case .en: "Quota runs out around \(emptyText)"
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
        case .en: "Thin buffer until \(resetText)"
        }
    }

    private static func safeRunwayHeadline(_ resetText: String, _ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "按当前速度，够用到 \(resetText) 刷新"
        case .zhHant: "依目前速度，可用到 \(resetText) 重設"
        case .en: "Quota lasts until \(resetText)"
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
