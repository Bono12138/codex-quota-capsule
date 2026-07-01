import Foundation

public enum QuotaLocale: String, Equatable, Sendable {
    case zhHans
    case zhHant
    case en

    public static func current(preferredLanguages: [String] = Locale.preferredLanguages) -> QuotaLocale {
        for language in preferredLanguages {
            let lowercased = language.lowercased()
            if lowercased.hasPrefix("zh-hant")
                || lowercased.contains("-tw")
                || lowercased.contains("-hk")
                || lowercased.contains("-mo") {
                return .zhHant
            }
            if lowercased.hasPrefix("zh-hans") || lowercased.hasPrefix("zh") {
                return .zhHans
            }
            if lowercased.hasPrefix("en") {
                return .en
            }
        }
        return .en
    }
}

public struct QuotaCopy: Equatable, Sendable {
    public let locale: QuotaLocale

    public init(locale: QuotaLocale) {
        self.locale = locale
    }

    public var notRefreshed: String {
        switch locale {
        case .zhHans: "尚未刷新"
        case .zhHant: "尚未重新整理"
        case .en: "Not refreshed yet"
        }
    }

    public var notAttempted: String {
        switch locale {
        case .zhHans: "尚未尝试"
        case .zhHant: "尚未嘗試"
        case .en: "No attempt yet"
        }
    }

    public var initialLoadingError: String {
        switch locale {
        case .zhHans: "启动中，正在读取 Codex 额度。"
        case .zhHant: "啟動中，正在讀取 Codex 額度。"
        case .en: "Starting up and reading Codex quota."
        }
    }

    public var unknownValue: String {
        switch locale {
        case .zhHans: "未知"
        case .zhHant: "未知"
        case .en: "Unknown"
        }
    }

    public var unknownError: String {
        switch locale {
        case .zhHans: "未知错误"
        case .zhHant: "未知錯誤"
        case .en: "Unknown error"
        }
    }

    public var loadingStatus: String {
        switch locale {
        case .zhHans: "读取中"
        case .zhHant: "讀取中"
        case .en: "Loading"
        }
    }

    public var loadingCompact: String {
        switch locale {
        case .zhHans: "正在读取 Codex 额度"
        case .zhHant: "正在讀取 Codex 額度"
        case .en: "Reading Codex quota"
        }
    }

    public var statusSafe: String {
        switch locale {
        case .zhHans: "安全"
        case .zhHant: "安全"
        case .en: "Safe"
        }
    }

    public var statusWatch: String {
        switch locale {
        case .zhHans: "注意"
        case .zhHant: "注意"
        case .en: "Watch"
        }
    }

    public var statusDanger: String {
        switch locale {
        case .zhHans: "危险"
        case .zhHant: "危險"
        case .en: "Danger"
        }
    }

    public var statusUnknown: String {
        switch locale {
        case .zhHans: "未知"
        case .zhHant: "未知"
        case .en: "Unknown"
        }
    }

    public var metricElapsed: String {
        switch locale {
        case .zhHans: "时间进度"
        case .zhHant: "時間進度"
        case .en: "Time elapsed"
        }
    }

    public var metricUsed: String {
        switch locale {
        case .zhHans: "额度已用"
        case .zhHant: "額度已用"
        case .en: "Quota used"
        }
    }

    public var metricPace: String {
        switch locale {
        case .zhHans: "当前速度"
        case .zhHant: "目前速度"
        case .en: "Current pace"
        }
    }

    public var metricResetBuffer: String {
        switch locale {
        case .zhHans: "刷新余量"
        case .zhHant: "重設餘量"
        case .en: "Reset buffer"
        }
    }

    public func statusLabel(for level: CapsuleLevel) -> String {
        switch level {
        case .safe: statusSafe
        case .watch: statusWatch
        case .danger: statusDanger
        case .unknown: statusUnknown
        }
    }

    public func sourceUnavailable(_ error: String) -> String {
        switch locale {
        case .zhHans: "Codex app-server 暂时不可用\n\(error)"
        case .zhHant: "Codex app-server 暫時無法使用\n\(error)"
        case .en: "Codex app-server is unavailable\n\(error)"
        }
    }

    public func sourceSuccess(_ lastRefreshText: String) -> String {
        switch locale {
        case .zhHans: "Codex app-server / rateLimits/read。成功更新：\(lastRefreshText)"
        case .zhHant: "Codex app-server / rateLimits/read。成功更新：\(lastRefreshText)"
        case .en: "Codex app-server / rateLimits/read. Updated: \(lastRefreshText)"
        }
    }

    public func sourceShowingLastSuccess(lastRefreshText: String, error: String) -> String {
        switch locale {
        case .zhHans: "Codex app-server / rateLimits/read。继续显示 \(lastRefreshText) 数据；最近失败：\(error)"
        case .zhHant: "Codex app-server / rateLimits/read。繼續顯示 \(lastRefreshText) 的資料；最近失敗：\(error)"
        case .en: "Codex app-server / rateLimits/read. Showing data from \(lastRefreshText); latest failure: \(error)"
        }
    }

    public var sourceName: String { "Codex app-server" }
    public var sourceEndpoint: String { "rateLimits/read" }

    public var sourceStatusLive: String {
        switch locale {
        case .zhHans: "实时读取成功"
        case .zhHant: "即時讀取成功"
        case .en: "Live read succeeded"
        }
    }

    public var sourceStatusShowingLastSuccess: String {
        switch locale {
        case .zhHans: "显示上次成功数据"
        case .zhHant: "顯示上次成功資料"
        case .en: "Showing last success"
        }
    }

    public var sourceStatusFailed: String {
        switch locale {
        case .zhHans: "读取失败"
        case .zhHant: "讀取失敗"
        case .en: "Read failed"
        }
    }

    public func sourceLatestFailure(_ error: String) -> String {
        switch locale {
        case .zhHans: "最近失败：\(error)"
        case .zhHant: "最近失敗：\(error)"
        case .en: "Latest failure: \(error)"
        }
    }

    public func sourceLastAttempt(_ lastAttemptText: String) -> String {
        switch locale {
        case .zhHans: "最近尝试 \(lastAttemptText)，每 60 秒自动刷新。"
        case .zhHant: "最近嘗試 \(lastAttemptText)，每 60 秒自動重新整理。"
        case .en: "Last attempt \(lastAttemptText). Auto-refreshes every 60 seconds."
        }
    }

    public var manualRefreshNote: String {
        switch locale {
        case .zhHans: "可从菜单栏手动刷新。"
        case .zhHant: "可從選單列手動重新整理。"
        case .en: "You can refresh manually from the menu bar."
        }
    }

    public var shortWindowTitle: String {
        switch locale {
        case .zhHans: "Codex · 5 小时窗口"
        case .zhHant: "Codex · 5 小時週期"
        case .en: "Codex · 5-hour window"
        }
    }

    public var weeklyRemainingTitle: String {
        switch locale {
        case .zhHans: "周额度余量"
        case .zhHant: "週額度餘量"
        case .en: "Weekly left"
        }
    }

    public var resetTimeTitle: String {
        switch locale {
        case .zhHans: "刷新时间"
        case .zhHant: "重設時間"
        case .en: "Reset time"
        }
    }

    public var successUpdateTitle: String {
        switch locale {
        case .zhHans: "成功更新"
        case .zhHant: "成功更新"
        case .en: "Last success"
        }
    }

    public var dataSourceTitle: String {
        switch locale {
        case .zhHans: "数据来源"
        case .zhHant: "資料來源"
        case .en: "Data source"
        }
    }

    public var sourceTitle: String {
        switch locale {
        case .zhHans: "来源"
        case .zhHant: "來源"
        case .en: "Source"
        }
    }

    public var endpointTitle: String {
        switch locale {
        case .zhHans: "接口"
        case .zhHant: "介面"
        case .en: "Endpoint"
        }
    }

    public var statusTitle: String {
        switch locale {
        case .zhHans: "状态"
        case .zhHant: "狀態"
        case .en: "Status"
        }
    }

    public var menuSourcePrefix: String {
        switch locale {
        case .zhHans: "来源"
        case .zhHant: "來源"
        case .en: "Source"
        }
    }

    public var lastUpdatePrefix: String {
        switch locale {
        case .zhHans: "上次更新"
        case .zhHant: "上次更新"
        case .en: "Last update"
        }
    }

    public var lastAttemptPrefix: String {
        switch locale {
        case .zhHans: "最近尝试"
        case .zhHant: "最近嘗試"
        case .en: "Last attempt"
        }
    }

    public var refreshNowAction: String {
        switch locale {
        case .zhHans: "立即刷新"
        case .zhHant: "立即重新整理"
        case .en: "Refresh now"
        }
    }

    public var toggleCapsuleAction: String {
        switch locale {
        case .zhHans: "显示/隐藏悬浮胶囊"
        case .zhHant: "顯示/隱藏懸浮膠囊"
        case .en: "Show/hide floating capsule"
        }
    }

    public var quitAction: String {
        switch locale {
        case .zhHans: "退出 Quota Capsule"
        case .zhHant: "退出 Quota Capsule"
        case .en: "Quit Quota Capsule"
        }
    }

    public var localPrivacyDescription: String {
        switch locale {
        case .zhHans: "本版本默认本地读取 Codex app-server，只显示脱敏额度窗口，不上传数据。"
        case .zhHant: "此版本預設在本機讀取 Codex app-server，只顯示去識別化的額度週期，不上傳資料。"
        case .en: "This version reads Codex app-server locally, shows only quota windows, and uploads no data."
        }
    }

    public var refreshQuotaAction: String {
        switch locale {
        case .zhHans: "刷新额度"
        case .zhHant: "重新整理額度"
        case .en: "Refresh quota"
        }
    }

    public var aboutFeedbackTitle: String {
        switch locale {
        case .zhHans: "关于与反馈"
        case .zhHant: "關於與回饋"
        case .en: "About & Feedback"
        }
    }

    public var authorLine: String {
        switch locale {
        case .zhHans: "作者：Bono MA"
        case .zhHant: "作者：Bono MA"
        case .en: "Author: Bono MA"
        }
    }

    public var emailLine: String {
        switch locale {
        case .zhHans: "邮箱：mmz1218bono@gmail.com"
        case .zhHant: "信箱：mmz1218bono@gmail.com"
        case .en: "Email: mmz1218bono@gmail.com"
        }
    }

    public var xLine: String {
        switch locale {
        case .zhHans: "X：@starlightsz0"
        case .zhHant: "X：@starlightsz0"
        case .en: "X: @starlightsz0"
        }
    }

    public var emailFeedbackAction: String {
        switch locale {
        case .zhHans: "邮件反馈"
        case .zhHant: "用 Email 回報"
        case .en: "Email feedback"
        }
    }

    public var githubIssuesAction: String {
        switch locale {
        case .zhHans: "打开 GitHub Issues"
        case .zhHant: "開啟 GitHub Issues"
        case .en: "Open GitHub Issues"
        }
    }

    public var openXAction: String {
        switch locale {
        case .zhHans: "打开 X 主页"
        case .zhHant: "開啟 X 個人頁"
        case .en: "Open X profile"
        }
    }
}
