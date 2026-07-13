import Foundation

public enum QuotaLocale: String, Equatable, Sendable {
    case zhHans
    case zhHant
    case en

    public static func current(preferredLanguages: [String] = Locale.preferredLanguages) -> QuotaLocale {
        supported(preferredLanguages: preferredLanguages) ?? .en
    }

    public static func supported(preferredLanguages: [String] = Locale.preferredLanguages) -> QuotaLocale? {
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
        return nil
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

    public var statusStale: String {
        switch locale {
        case .zhHans: "已过期"
        case .zhHant: "已過期"
        case .en: "Stale"
        }
    }

    public var statusWaiting: String {
        switch locale {
        case .zhHans: "待开始"
        case .zhHant: "待開始"
        case .en: "Waiting"
        }
    }

    public var waitingValue: String {
        statusWaiting
    }

    public var activeShortWindowMissingError: String {
        switch locale {
        case .zhHans: "活动中的 5 小时窗口暂时没有出现在最新响应中，应用会自动重试。"
        case .zhHant: "進行中的 5 小時週期暫時沒有出現在最新回應中，App 會自動重試。"
        case .en: "The active 5-hour window is temporarily missing from the latest response. The app will retry automatically."
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
        case .en: "Live"
        }
    }

    public var sourceStatusShowingLastSuccess: String {
        switch locale {
        case .zhHans: "显示上次成功数据"
        case .zhHant: "顯示上次成功資料"
        case .en: "Last success"
        }
    }

    public var sourceStatusFailed: String {
        switch locale {
        case .zhHans: "读取失败"
        case .zhHant: "讀取失敗"
        case .en: "Failed"
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
        case .zhHans: "可从菜单栏或展开面板手动刷新。"
        case .zhHant: "可從選單列或展開面板手動重新整理。"
        case .en: "Manual refresh is in the menu bar or detail panel."
        }
    }

    public var authorProfileAction: String {
        switch locale {
        case .zhHans: "作者 X 主页"
        case .zhHant: "作者 X 個人頁"
        case .en: "Author X profile"
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

    public var weeklyProjectionTitle: String {
        switch locale {
        case .zhHans: "本周压力"
        case .zhHant: "本週壓力"
        case .en: "Weekly pressure"
        }
    }

    public var weeklyProjectionUnavailable: String {
        switch locale {
        case .zhHans: "暂时没有周窗口数据。"
        case .zhHant: "暫時沒有週額度資料。"
        case .en: "Weekly quota data is unavailable."
        }
    }

    public func weeklyProjectionWillLast(usedPercent: Int, projectedRemaining: Int) -> String {
        if usedPercent == 0 {
            return switch locale {
            case .zhHans: "本周读数低于 1%，按上限估算周刷新时至少剩 \(projectedRemaining)%"
            case .zhHant: "本週讀數低於 1%，按上限估算週重設時至少剩 \(projectedRemaining)%"
            case .en: "Weekly usage is below 1%; the upper-bound estimate leaves at least \(projectedRemaining)% at reset"
            }
        }
        return switch locale {
        case .zhHans: "本周已用 \(usedPercent)%，按当前速度预计周刷新时剩 \(projectedRemaining)%"
        case .zhHant: "本週已用 \(usedPercent)%，依目前速度預計週重設時剩 \(projectedRemaining)%"
        case .en: "Weekly used \(usedPercent)%; projected \(projectedRemaining)% left at reset"
        }
    }

    public func weeklyProjectionWillRunOut(emptyTime: String) -> String {
        switch locale {
        case .zhHans: "按当前速度，本周额度预计 \(emptyTime) 用完"
        case .zhHant: "依目前速度，本週額度預計 \(emptyTime) 用完"
        case .en: "At this pace, weekly quota runs out around \(emptyTime)"
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
        case .zhHans: "本机会持续记录额度快照和产品交互，用来显示趋势、诊断问题。基础诊断默认发送版本、语言、读取成败和粗略错误类型；产品改进数据只在你同意后发送。"
        case .zhHant: "本機會持續記錄額度快照和產品互動，用來顯示趨勢、診斷問題。基礎診斷預設傳送版本、語言、讀取成敗和粗略錯誤類型；產品改善資料只在你同意後傳送。"
        case .en: "The app keeps quota snapshots and product interactions locally for trends and diagnostics. Basic diagnostics sends version, language, read success or failure, and broad error type by default; product improvement data sends after your consent."
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

    public var productIntroTitle: String {
        switch locale {
        case .zhHans: "产品介绍"
        case .zhHant: "產品介紹"
        case .en: "Product overview"
        }
    }

    public var productIntroBody: String {
        switch locale {
        case .zhHans: "Quota Capsule 会常驻 Mac 桌面和菜单栏，把 Codex 的 5 小时窗口和周窗口转换成可操作判断：按当前速度，能不能撑到下一次刷新。"
        case .zhHant: "Quota Capsule 會常駐 Mac 桌面和選單列，把 Codex 的 5 小時週期和週額度轉換成可操作判斷：依目前速度，能不能撐到下一次重設。"
        case .en: "Quota Capsule stays on your Mac desktop and menu bar, turning Codex 5-hour and weekly quota windows into a practical answer: whether the current pace can last until reset."
        }
    }

    public var betaThanksTitle: String {
        switch locale {
        case .zhHans: "感谢参与内测"
        case .zhHant: "感謝參與內測"
        case .en: "Thanks for testing"
        }
    }

    public var betaThanksBody: String {
        switch locale {
        case .zhHans: "当前版本还在内测阶段，读数、交互和文案都可能继续调整。欢迎把安装问题、误判、看不懂的提示和你期待的功能发给我。"
        case .zhHant: "目前版本仍在內測階段，讀數、互動和文案都可能繼續調整。歡迎把安裝問題、誤判、看不懂的提示和你期待的功能傳給我。"
        case .en: "This is still an internal test build. Readouts, interactions, and copy may change. Please send install issues, confusing messages, wrong judgments, and feature requests."
        }
    }

    public var currentVersionFeaturesTitle: String {
        switch locale {
        case .zhHans: "你可以用这些能力"
        case .zhHant: "你可以使用這些功能"
        case .en: "What you can use now"
        }
    }

    public var currentVersionFeatures: [String] {
        switch locale {
        case .zhHans:
            [
                "读取 Codex app-server 的 5 小时窗口和周窗口。",
                "桌面悬浮胶囊、菜单栏短状态和展开详情面板。",
                "自动刷新、手动刷新和读取失败时保留上次成功数据。",
                "靠边停靠迷你形态、胶囊宽度调整和三语界面。",
                "展开面板提供刷新、反馈和更多操作；语言、引导、作者、关于和退出收在更多操作里。",
                "本地历史记录、基础诊断和可选产品改进数据。"
            ]
        case .zhHant:
            [
                "讀取 Codex app-server 的 5 小時週期和週額度。",
                "桌面懸浮膠囊、選單列短狀態和展開詳細面板。",
                "自動重新整理、手動重新整理，讀取失敗時保留上次成功資料。",
                "靠邊停靠迷你形態、膠囊寬度調整和三語介面。",
                "展開面板提供重新整理、回饋和更多操作；語言、引導、作者、關於和退出收在更多操作裡。",
                "本機歷史記錄、基礎診斷和可選產品改善資料。"
            ]
        case .en:
            [
                "Reads Codex app-server 5-hour and weekly quota windows.",
                "Desktop floating capsule, short menu bar status, and detail panel.",
                "Auto refresh, manual refresh, and last-success fallback after read failures.",
                "Edge-docked mini state, adjustable capsule width, and three interface languages.",
                "Refresh, feedback, and More actions in the detail panel; language, guide, author, about, and quit live under More actions.",
                "Local history, basic diagnostics, and optional product improvement analytics."
            ]
        }
    }

    public var futureVersionFeaturesTitle: String {
        switch locale {
        case .zhHans: "接下来会继续改进"
        case .zhHant: "接下來會繼續改善"
        case .en: "What is coming next"
        }
    }

    public var futureVersionFeatures: [String] {
        switch locale {
        case .zhHans:
            [
                "更深入的新手引导和按行为触发的功能提示。",
                "开机自启动设置和更完整的安装引导。",
                "历史趋势、使用节奏复盘和更细的异常诊断。",
                "公开仓库分发、内测渠道和正式发布流程。",
                "更多 agent provider adapter。"
            ]
        case .zhHant:
            [
                "更深入的新手引導和依行為觸發的功能提示。",
                "開機自動啟動設定和更完整的安裝引導。",
                "歷史趨勢、使用節奏回顧和更細的異常診斷。",
                "公開 repo 分發、內測渠道和正式發布流程。",
                "更多 agent provider adapter。"
            ]
        case .en:
            [
                "Deeper onboarding and behavior-triggered guidance.",
                "Launch-at-login setting and fuller install guidance.",
                "History trends, usage reviews, and more precise diagnostics.",
                "Public repository distribution, test channel, and release workflow.",
                "More agent provider adapters."
            ]
        }
    }

    public var aboutAuthorTitle: String {
        switch locale {
        case .zhHans: "作者"
        case .zhHant: "作者"
        case .en: "Author"
        }
    }

    public var aboutAuthorBody: String {
        switch locale {
        case .zhHans: "我是 Bono MA。这个项目会持续开源迭代，欢迎通过 GitHub Issues、邮件、X 或抖音把问题和想法发给我。"
        case .zhHant: "我是 Bono MA。這個專案會持續開源迭代，歡迎透過 GitHub Issues、Email、X 或抖音把問題和想法傳給我。"
        case .en: "I am Bono MA. This project will keep evolving in open source. Send issues and ideas through GitHub Issues, email, X, or Douyin."
        }
    }

    public var contactAuthorTitle: String {
        switch locale {
        case .zhHans: "联系作者"
        case .zhHant: "聯絡作者"
        case .en: "Contact author"
        }
    }

    public var menuFeedbackTitle: String {
        switch locale {
        case .zhHans: "反馈入口"
        case .zhHant: "回饋入口"
        case .en: "Feedback"
        }
    }

    public var languageMenuTitle: String {
        switch locale {
        case .zhHans: "Language / 语言"
        case .zhHant: "Language / 語言"
        case .en: "Language"
        }
    }

    public var languageSimplifiedAssistiveLabel: String {
        switch locale {
        case .zhHans: "简体中文"
        case .zhHant: "簡體中文"
        case .en: "Simplified Chinese"
        }
    }

    public var languageTraditionalAssistiveLabel: String {
        switch locale {
        case .zhHans: "繁体中文"
        case .zhHant: "繁體中文"
        case .en: "Traditional Chinese"
        }
    }

    public var languageEnglishAssistiveLabel: String {
        switch locale {
        case .zhHans: "英文"
        case .zhHant: "英文"
        case .en: "English"
        }
    }

    public var resizeCapsuleHelp: String {
        switch locale {
        case .zhHans: "调整胶囊宽度"
        case .zhHant: "調整膠囊寬度"
        case .en: "Resize capsule"
        }
    }

    public var authorLine: String {
        switch locale {
        case .zhHans: "作者：Bono MA"
        case .zhHant: "作者：Bono MA"
        case .en: "Author: Bono MA"
        }
    }

    public var authorMenuHint: String {
        switch locale {
        case .zhHans: "Bono MA · 反馈和更新"
        case .zhHant: "Bono MA · 回饋和更新"
        case .en: "Bono MA · Feedback and updates"
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

    public var douyinLine: String {
        switch locale {
        case .zhHans: "抖音：火腿肠（huotuichang439）"
        case .zhHant: "抖音：火腿腸（huotuichang439）"
        case .en: "Douyin: 火腿肠 (huotuichang439)"
        }
    }

    public var douyinQrHint: String {
        switch locale {
        case .zhHans: "扫码关注，也可以把新的意见发给我。"
        case .zhHant: "掃碼追蹤，也可以把新的意見傳給我。"
        case .en: "Scan to follow on Douyin and send product feedback."
        }
    }

    public var emailFeedbackAction: String {
        switch locale {
        case .zhHans: "邮件反馈"
        case .zhHant: "用 Email 回報"
        case .en: "Email feedback"
        }
    }

    public var panelQuickActionsTitle: String {
        switch locale {
        case .zhHans: "操作"
        case .zhHant: "操作"
        case .en: "Actions"
        }
    }

    public var moreActionsTitle: String {
        switch locale {
        case .zhHans: "更多操作"
        case .zhHant: "更多操作"
        case .en: "More actions"
        }
    }

    public var openStatusMenuAction: String {
        switch locale {
        case .zhHans: "打开状态栏菜单"
        case .zhHant: "開啟選單列選單"
        case .en: "Open menu bar menu"
        }
    }

    public var submitFeedbackAction: String {
        switch locale {
        case .zhHans: "提交反馈"
        case .zhHant: "送出回饋"
        case .en: "Send feedback"
        }
    }

    public var feedbackAlternativeHint: String {
        switch locale {
        case .zhHans: "没有 GitHub 账号也可以用邮件、X 或抖音把问题发给我。"
        case .zhHant: "沒有 GitHub 帳號也可以用 Email、X 或抖音把問題傳給我。"
        case .en: "You can also send feedback by email, X, or Douyin without a GitHub account."
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

    public var codexFeedbackAction: String {
        switch locale {
        case .zhHans: "让 Codex 整理"
        case .zhHant: "讓 Codex 整理"
        case .en: "Prepare with Codex"
        }
    }

    public var codexFeedbackCopiedAction: String {
        switch locale {
        case .zhHans: "反馈已准备好"
        case .zhHant: "回饋已準備好"
        case .en: "Feedback prepared"
        }
    }

    public var codexFeedbackHint: String {
        switch locale {
        case .zhHans: "打开 GitHub Issue 或邮件草稿，并复制一段可交给 Codex 的整理提示词。"
        case .zhHant: "開啟 GitHub Issue 或 Email 草稿，並複製一段可交給 Codex 的整理提示詞。"
        case .en: "Opens a GitHub Issue or email draft and copies a safe prompt for Codex."
        }
    }

    public var assistedFeedbackStartedMessage: String {
        switch locale {
        case .zhHans: "已打开反馈页面，也复制了给 Codex 的整理提示词。你可以直接补一句问题现象后提交。"
        case .zhHant: "已開啟回饋頁面，也複製了給 Codex 的整理提示詞。你可以直接補一句問題現象後送出。"
        case .en: "Feedback is open, and a Codex prompt was copied. Add one sentence about what happened, then submit."
        }
    }

    public var assistedFeedbackEmailMessage: String {
        switch locale {
        case .zhHans: "已打开邮件草稿，也复制了给 Codex 的整理提示词。你可以直接补一句问题现象后发送。"
        case .zhHant: "已開啟 Email 草稿，也複製了給 Codex 的整理提示詞。你可以直接補一句問題現象後寄出。"
        case .en: "An email draft is open, and a Codex prompt was copied. Add one sentence about what happened, then send it."
        }
    }

    public var feedbackNudgeTitle: String {
        switch locale {
        case .zhHans: "使用还顺手吗？"
        case .zhHant: "用起來還順手嗎？"
        case .en: "How is it working?"
        }
    }

    public var feedbackNudgeMessage: String {
        switch locale {
        case .zhHans: "如果遇到报错、看不懂的提示，或者有改进建议，可以直接发给我。"
        case .zhHant: "如果遇到錯誤、看不懂的提示，或者有改善建議，可以直接傳給我。"
        case .en: "If you saw an error, confusing message, or improvement idea, you can send it to me."
        }
    }

    public var feedbackNudgeLaterAction: String {
        switch locale {
        case .zhHans: "稍后"
        case .zhHant: "稍後"
        case .en: "Later"
        }
    }

    public var feedbackNudgeOpenAction: String {
        switch locale {
        case .zhHans: "打开反馈入口"
        case .zhHant: "開啟回饋入口"
        case .en: "Open feedback"
        }
    }

    public var feedbackNudgeCodexAction: String {
        switch locale {
        case .zhHans: "让 Codex 整理"
        case .zhHant: "讓 Codex 整理"
        case .en: "Prepare with Codex"
        }
    }

    public var feedbackNudgeCopiedMessage: String {
        switch locale {
        case .zhHans: "提示词已复制。把它交给你的 Codex，它会帮你整理反馈内容。"
        case .zhHant: "提示詞已複製。把它交給你的 Codex，它會幫你整理回饋內容。"
        case .en: "Prompt copied. Give it to your Codex and it will help prepare the feedback."
        }
    }

    public var copyDouyinIdAction: String {
        switch locale {
        case .zhHans: "huotuichang439"
        case .zhHant: "huotuichang439"
        case .en: "huotuichang439"
        }
    }

    public var openDouyinAction: String {
        switch locale {
        case .zhHans: "打开抖音"
        case .zhHant: "開啟抖音"
        case .en: "Open Douyin"
        }
    }

    public var userGuideAction: String {
        switch locale {
        case .zhHans: "查看新手引导"
        case .zhHant: "查看新手引導"
        case .en: "View first-run guide"
        }
    }

    public var onboardingTitle: String {
        switch locale {
        case .zhHans: "先把 Quota Capsule 放到顺手的位置"
        case .zhHant: "先把 Quota Capsule 放到順手的位置"
        case .en: "Set up Quota Capsule"
        }
    }

    public var onboardingSubtitle: String {
        switch locale {
        case .zhHans: "它会常驻桌面，帮你判断当前 Codex 用量速度能不能撑到下一次刷新。"
        case .zhHant: "它會常駐桌面，幫你判斷目前 Codex 用量速度能不能撐到下一次重設。"
        case .en: "It stays on your desktop and shows whether your current Codex pace can last until reset."
        }
    }

    public var onboardingAuthorIntro: String {
        switch locale {
        case .zhHans: "作者 Bono MA。反馈可以发到 GitHub、邮箱、X 或抖音。"
        case .zhHant: "作者 Bono MA。回饋可以傳到 GitHub、信箱、X 或抖音。"
        case .en: "Made by Bono MA. Send feedback through GitHub, email, X, or Douyin."
        }
    }

    public var onboardingAuthorActionTitle: String {
        switch locale {
        case .zhHans: "关注作者和继续反馈"
        case .zhHant: "追蹤作者並持續回饋"
        case .en: "Follow and send feedback"
        }
    }

    public var onboardingAuthorActionBody: String {
        switch locale {
        case .zhHans: "内测会持续更新。关注 X 或抖音看进展；反馈按钮会准备公开 Issue 或邮件草稿。"
        case .zhHant: "內測會持續更新。追蹤 X 或抖音看進展；回饋按鈕會準備公開 Issue 或 Email 草稿。"
        case .en: "Follow X or Douyin for updates; the feedback button prepares a public Issue or email draft."
        }
    }

    public var onboardingLocalRead: String {
        switch locale {
        case .zhHans: "只读本机 Codex app-server 的额度窗口。"
        case .zhHant: "只讀本機 Codex app-server 的額度週期。"
        case .en: "Reads local Codex app-server quota windows only."
        }
    }

    public var onboardingPrivacy: String {
        switch locale {
        case .zhHans: "prompt、session、token 和 cookie 留在本机。"
        case .zhHant: "prompt、session、token 和 cookie 留在本機。"
        case .en: "Prompts, sessions, tokens, and cookies stay on this Mac."
        }
    }

    public var onboardingStatus: String {
        switch locale {
        case .zhHans: "颜色表示当前速度是否安全，百分比表示 5 小时窗口已用。"
        case .zhHant: "顏色表示目前速度是否安全，百分比表示 5 小時週期已用。"
        case .en: "Color shows pace risk; the percent is 5-hour usage."
        }
    }

    public var onboardingInteraction: String {
        switch locale {
        case .zhHans: "点击胶囊看原因；拖两侧调整宽度，拖到边缘进入迷你形态。"
        case .zhHant: "點擊膠囊看原因；拖兩側調整寬度，拖到邊緣進入迷你形態。"
        case .en: "Click for details; drag side handles to resize, or drag to an edge for mini mode."
        }
    }

    public var onboardingDiagnosticTitle: String {
        switch locale {
        case .zhHans: "当前读取状态"
        case .zhHant: "目前讀取狀態"
        case .en: "Current read status"
        }
    }

    public var onboardingStartAction: String {
        switch locale {
        case .zhHans: "开始使用"
        case .zhHant: "開始使用"
        case .en: "Start using"
        }
    }

    public var onboardingPrivacyAction: String {
        switch locale {
        case .zhHans: "数据采集设置"
        case .zhHant: "資料收集設定"
        case .en: "Data settings"
        }
    }

    public var languageSelectionTitle: String {
        switch locale {
        case .zhHans: "选择界面语言"
        case .zhHant: "選擇介面語言"
        case .en: "Choose interface language"
        }
    }

    public var languageSelectionSubtitle: String {
        switch locale {
        case .zhHans: "先选择你想使用的界面语言，后续可以从菜单栏随时切换。"
        case .zhHant: "先選擇你想使用的介面語言，之後可以從選單列隨時切換。"
        case .en: "Choose the interface language first. You can change it later from the menu bar."
        }
    }

    public var analyticsConsentTitle: String {
        switch locale {
        case .zhHans: "让产品继续变好"
        case .zhHant: "讓產品繼續變好"
        case .en: "Keep improving the product"
        }
    }

    public var analyticsConsentBody: String {
        switch locale {
        case .zhHans: "基础诊断默认记录版本、系统语言、读取成功或失败，帮助我发现安装和数据源问题。允许产品改进数据后，还会发送常驻时长、展开次数、引导完成情况和反馈入口点击，用来判断哪些设计真的有用。prompt、session、token、cookie、文件路径、项目名、窗口标题和代码内容留在本机。"
        case .zhHant: "基礎診斷預設會記錄版本、系統語言、讀取成功或失敗，協助我發現安裝和資料來源問題。允許產品改善資料後，還會傳送常駐時長、展開次數、引導完成狀態和回饋入口點擊，用來判斷哪些設計真的有用。prompt、session、token、cookie、檔案路徑、專案名稱、視窗標題和程式碼內容留在本機。"
        case .en: "Basic diagnostics records version, system language, and read success or failure by default so installation and source issues can be found. If you allow product improvement data, the app also sends desktop residency, expand count, onboarding progress, and feedback clicks to show which designs are useful. Prompts, sessions, tokens, cookies, file paths, project names, window titles, and code stay on this Mac."
        }
    }

    public var analyticsEssentialTitle: String {
        switch locale {
        case .zhHans: "基础诊断已开启"
        case .zhHant: "基礎診斷已開啟"
        case .en: "Basic diagnostics is on"
        }
    }

    public var analyticsEssentialBody: String {
        switch locale {
        case .zhHans: "记录版本、界面语言、读取成功或失败、粗略错误类型，用来发现安装和数据源问题。"
        case .zhHant: "記錄版本、介面語言、讀取成功或失敗、粗略錯誤類型，用來發現安裝和資料來源問題。"
        case .en: "Records version, interface language, read success or failure, and broad error type for install and source diagnostics."
        }
    }

    public var analyticsProductTitle: String {
        switch locale {
        case .zhHans: "推荐开启产品改进数据"
        case .zhHant: "建議開啟產品改善資料"
        case .en: "Recommended product improvement data"
        }
    }

    public var analyticsProductBody: String {
        switch locale {
        case .zhHans: "发送常驻时长、展开次数、引导进度、反馈入口点击和尺寸调整，帮助判断哪些设计值得保留。"
        case .zhHant: "傳送常駐時長、展開次數、引導進度、回饋入口點擊和尺寸調整，協助判斷哪些設計值得保留。"
        case .en: "Sends desktop residency, expand count, onboarding progress, feedback clicks, and resize use to guide product decisions."
        }
    }

    public var analyticsSensitiveBoundary: String {
        switch locale {
        case .zhHans: "prompt、session、token、cookie、文件路径、项目名、窗口标题和代码内容留在本机。"
        case .zhHant: "prompt、session、token、cookie、檔案路徑、專案名稱、視窗標題和程式碼內容留在本機。"
        case .en: "Prompts, sessions, tokens, cookies, file paths, project names, window titles, and code stay on this Mac."
        }
    }

    public var analyticsAllowAction: String {
        switch locale {
        case .zhHans: "允许，帮你改得更好"
        case .zhHant: "允許，幫你改得更好"
        case .en: "Allow and improve it"
        }
    }

    public var analyticsDenyAction: String {
        switch locale {
        case .zhHans: "稍后再说"
        case .zhHant: "稍後再說"
        case .en: "Decide later"
        }
    }

    public var analyticsBasicSummaryText: String {
        switch locale {
        case .zhHans: "当前发送基础诊断。开启产品改进数据后，我可以看到常驻、展开、引导和反馈入口是否真的有用。"
        case .zhHant: "目前傳送基礎診斷。開啟產品改善資料後，我可以看到常駐、展開、引導和回饋入口是否真的有用。"
        case .en: "Basic diagnostics is active. Product improvement data shows whether desktop residency, expansion, onboarding, and feedback entry points are useful."
        }
    }

    public var advancedDataSettingsTitle: String {
        switch locale {
        case .zhHans: "高级数据设置"
        case .zhHant: "進階資料設定"
        case .en: "Advanced data settings"
        }
    }

    public var localDataPrivacyAuthorizationTitle: String {
        switch locale {
        case .zhHans: "本地数据与隐私授权"
        case .zhHant: "本機資料與隱私授權"
        case .en: "Local data & privacy permissions"
        }
    }

    public var analyticsRevokeDescription: String {
        switch locale {
        case .zhHans: "这里可以撤销产品改进数据授权。基础诊断会继续用于安装和读取问题定位。"
        case .zhHant: "這裡可以撤銷產品改善資料授權。基礎診斷會繼續用於安裝和讀取問題定位。"
        case .en: "You can revoke product improvement analytics here. Basic diagnostics still helps diagnose install and quota-read issues."
        }
    }

    public var analyticsRevokeAction: String {
        switch locale {
        case .zhHans: "不参与产品改进计划"
        case .zhHant: "不參與產品改善計畫"
        case .en: "Leave product improvement program"
        }
    }

    public var cancelAction: String {
        switch locale {
        case .zhHans: "取消"
        case .zhHant: "取消"
        case .en: "Cancel"
        }
    }

    public var doneAction: String {
        switch locale {
        case .zhHans: "知道了"
        case .zhHant: "知道了"
        case .en: "Got it"
        }
    }

    public var keepParticipatingAction: String {
        switch locale {
        case .zhHans: "继续参与"
        case .zhHant: "繼續參與"
        case .en: "Keep participating"
        }
    }

    public var keepLocalHistoryAction: String {
        switch locale {
        case .zhHans: "保留本地历史"
        case .zhHant: "保留本機歷史"
        case .en: "Keep local history"
        }
    }

    public var confirmRevokeAnalyticsTitle: String {
        switch locale {
        case .zhHans: "确认不参与产品改进计划？"
        case .zhHant: "確認不參與產品改善計畫？"
        case .en: "Leave the product improvement program?"
        }
    }

    public var confirmRevokeAnalyticsMessage: String {
        switch locale {
        case .zhHans: "撤销后，我将只能收到基础诊断数据，较难判断哪些交互真的有用。你的本地额度历史和基础诊断会继续保留。"
        case .zhHant: "撤銷後，我將只能收到基礎診斷資料，較難判斷哪些互動真的有用。你的本機額度歷史和基礎診斷會繼續保留。"
        case .en: "After this, only basic diagnostics will be sent, making it harder to understand which interactions are useful. Your local quota history and basic diagnostics remain."
        }
    }

    public var confirmClearLocalHistoryTitle: String {
        switch locale {
        case .zhHans: "确认清空本地历史？"
        case .zhHant: "確認清空本機歷史？"
        case .en: "Clear local history?"
        }
    }

    public var confirmClearLocalHistoryMessage: String {
        switch locale {
        case .zhHans: "清空后，本机趋势、历史样本和未发送事件会被删除。之后仍会从新的额度读取开始重新记录。"
        case .zhHant: "清空後，本機趨勢、歷史樣本和未傳送事件會被刪除。之後仍會從新的額度讀取開始重新記錄。"
        case .en: "This deletes local trends, history samples, and unsent events. New quota reads will start recording again afterward."
        }
    }

    public var analyticsCurrentChoiceTitle: String {
        switch locale {
        case .zhHans: "当前选择"
        case .zhHant: "目前選擇"
        case .en: "Current choice"
        }
    }

    public var analyticsGrantedText: String {
        switch locale {
        case .zhHans: "已允许发送产品使用数据"
        case .zhHant: "已允許傳送產品使用資料"
        case .en: "Product analytics allowed"
        }
    }

    public var analyticsDeniedText: String {
        switch locale {
        case .zhHans: "基础诊断"
        case .zhHant: "基礎診斷"
        case .en: "Basic diagnostics"
        }
    }

    public var analyticsUndecidedText: String {
        switch locale {
        case .zhHans: "默认基础诊断"
        case .zhHant: "預設基礎診斷"
        case .en: "Basic diagnostics by default"
        }
    }

    public var onboardingSkipAction: String {
        switch locale {
        case .zhHans: "跳过"
        case .zhHant: "略過"
        case .en: "Skip"
        }
    }

    public var onboardingNextAction: String {
        switch locale {
        case .zhHans: "下一步"
        case .zhHant: "下一步"
        case .en: "Next"
        }
    }

    public var onboardingBackAction: String {
        switch locale {
        case .zhHans: "上一步"
        case .zhHant: "上一步"
        case .en: "Back"
        }
    }

    public var onboardingCapsuleStepTitle: String {
        switch locale {
        case .zhHans: "常驻胶囊"
        case .zhHant: "常駐膠囊"
        case .en: "Floating capsule"
        }
    }

    public var onboardingCapsuleStepBody: String {
        switch locale {
        case .zhHans: "收起态显示状态、5 小时已用比例和时间/用量对比。两侧把手可调整宽度，拖到边缘可进入迷你形态。"
        case .zhHant: "收起態顯示狀態、5 小時已用比例和時間／用量對比。兩側把手可調整寬度，拖到邊緣可進入迷你形態。"
        case .en: "Collapsed mode shows status, 5-hour usage, and time-vs-use tracks. Side handles resize it; edge drag enters mini mode."
        }
    }

    public var onboardingDetailStepTitle: String {
        switch locale {
        case .zhHans: "展开后看原因"
        case .zhHant: "展開後看原因"
        case .en: "Open for the reason"
        }
    }

    public var onboardingDetailStepBody: String {
        switch locale {
        case .zhHans: "详情面板解释判断来源：时间进度、额度已用、速度、周余量、刷新时间、最近更新和数据来源。"
        case .zhHant: "詳細面板會解釋判斷來源：時間進度、額度已用、速度、週餘量、重設時間、最近更新和資料來源。"
        case .en: "Details show elapsed time, used quota, pace, weekly left, reset time, last update, and source."
        }
    }

    public var onboardingWeeklyStepTitle: String {
        switch locale {
        case .zhHans: "周预测放在低注意力位置"
        case .zhHant: "週預測放在低注意力位置"
        case .en: "Weekly projection stays quiet"
        }
    }

    public var onboardingWeeklyStepBody: String {
        switch locale {
        case .zhHans: "5 小时窗口负责当下判断；本周压力只在需要时辅助查看。"
        case .zhHant: "5 小時週期負責當下判斷；本週壓力只在需要時輔助查看。"
        case .en: "The 5-hour window drives the current call. Weekly pressure is available when you need it."
        }
    }

    public var onboardingMenuStepTitle: String {
        switch locale {
        case .zhHans: "菜单栏和面板互为备份"
        case .zhHant: "選單列和面板互為備份"
        case .en: "Menu bar and panel back each other up"
        }
    }

    public var onboardingMenuStepBody: String {
        switch locale {
        case .zhHans: "菜单栏显示短状态和已用比例。展开面板提供刷新、提交反馈和更多操作；找不到菜单栏时，更多操作里也能进入语言、联系作者、关于反馈和退出。"
        case .zhHant: "選單列顯示短狀態和已用比例。展開面板提供重新整理、送出回饋和更多操作；找不到選單列時，更多操作裡也能進入語言、聯絡作者、關於回饋和退出。"
        case .en: "The menu bar shows short status and usage. The detail panel provides refresh, send feedback, and More actions; More actions keeps language, contact, about, and quit available when the menu bar is hard to find."
        }
    }

    public var onboardingFeedbackStepTitle: String {
        switch locale {
        case .zhHans: "把问题发给我"
        case .zhHant: "把問題傳給我"
        case .en: "Send feedback"
        }
    }

    public var onboardingFeedbackStepBody: String {
        switch locale {
        case .zhHans: "最后一步提供统一反馈入口、Email、X、抖音、抖音号复制和 Codex 整理提示词。"
        case .zhHant: "最後一步提供統一回饋入口、Email、X、抖音、抖音號複製和 Codex 整理提示詞。"
        case .en: "Use the unified feedback entry, email, X, Douyin, copied Douyin ID, or the Codex prompt."
        }
    }

    public var douyinCopyHint: String {
        switch locale {
        case .zhHans: "点击抖音号复制"
        case .zhHant: "點擊抖音號複製"
        case .en: "Click the Douyin ID to copy"
        }
    }

    public var douyinCopiedHint: String {
        switch locale {
        case .zhHans: "已复制，打开抖音搜索即可"
        case .zhHant: "已複製，開啟抖音搜尋即可"
        case .en: "Copied. Open Douyin and search for it."
        }
    }

    public var douyinCopiedShortAction: String {
        switch locale {
        case .zhHans: "已复制"
        case .zhHant: "已複製"
        case .en: "Copied"
        }
    }

    public var localHistoryTitle: String {
        switch locale {
        case .zhHans: "本地历史数据"
        case .zhHant: "本機歷史資料"
        case .en: "Local history"
        }
    }

    public var clearLocalHistoryAction: String {
        switch locale {
        case .zhHans: "清空本地历史"
        case .zhHant: "清空本機歷史"
        case .en: "Clear local history"
        }
    }

    public func historyDatabaseSize(_ size: String) -> String {
        switch locale {
        case .zhHans: "当前历史库大小：\(size)"
        case .zhHant: "目前歷史庫大小：\(size)"
        case .en: "Current history size: \(size)"
        }
    }

    public var compactPaceTitle: String {
        switch locale {
        case .zhHans: "节奏"
        case .zhHant: "節奏"
        case .en: "Pace"
        }
    }

    public var compactTimeLabel: String {
        switch locale {
        case .zhHans: "时间"
        case .zhHant: "時間"
        case .en: "Time"
        }
    }

    public var compactUsageLabel: String {
        switch locale {
        case .zhHans: "已用"
        case .zhHant: "已用"
        case .en: "Used"
        }
    }

    public var compactUsageTrackLabel: String {
        switch locale {
        case .zhHans: "用量"
        case .zhHant: "用量"
        case .en: "Use"
        }
    }

    public func compactUsedBadge(_ percent: Int) -> String {
        let value = percent == 0 ? "<1%" : "\(percent)%"
        return compactUsedBadge(value: value)
    }

    public func compactUsedBadge(value: String) -> String {
        return switch locale {
            case .zhHans: "已用 \(value)"
        case .zhHant: "已用 \(value)"
        case .en: "Used \(value)"
        }
    }
}
