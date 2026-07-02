import AppKit
import Foundation

enum FeedbackDestinations {
    static let authorEmail = "mmz1218bono@gmail.com"
    static let authorXURL = URL(string: "https://x.com/starlightsz0")!
    static let douyinID = "huotuichang439"
    static let douyinURL = URL(string: "https://v.douyin.com/Alo9NohbnoY/")!
}

extension Notification.Name {
    static let quotaCapsuleShowAboutFeedback = Notification.Name("QuotaCapsuleShowAboutFeedback")
    static let quotaCapsuleShowContactAuthor = Notification.Name("QuotaCapsuleShowContactAuthor")
    static let quotaCapsuleShowAdvancedDataSettings = Notification.Name("QuotaCapsuleShowAdvancedDataSettings")
    static let quotaCapsuleRequestFeedbackNudge = Notification.Name("QuotaCapsuleRequestFeedbackNudge")
}

@MainActor
func copyCodexFeedbackPromptToClipboard(store: QuotaStore) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(codexFeedbackPrompt(for: store), forType: .string)
    store.recordFeedbackClick("codex_prompt")
}

@MainActor
func codexFeedbackPrompt(for store: QuotaStore) -> String {
    switch store.copy.locale {
    case .zhHans:
        return """
        请帮我给 Quota Capsule 作者 Bono MA 整理一份产品反馈。

        反馈目标：
        - \(feedbackIssueTargetLine(for: store))
        - 邮箱：\(FeedbackDestinations.authorEmail)
        - 作者 X：\(FeedbackDestinations.authorXURL.absoluteString)

        请先向我确认问题现象、复现步骤、预期表现、实际表现、截图或录屏是否可以附上。然后帮我整理成一份清楚的反馈。如果我同意公开提交，就优先帮我打开或创建 GitHub Issue；如果不适合公开，就帮我起草邮件。

        安全边界：
        - 不要读取或发送 token、cookie、session、prompt、代码内容、项目路径、窗口标题、私有仓库地址。
        - 只使用我明确提供的截图、录屏、错误信息和下面这段应用状态。

        应用状态：
        - 应用：\(store.appDisplayName)
        - 发布渠道：\(store.releaseChannel.rawValue)
        - 当前判断：\(store.visibleStatusText)
        - 数据源状态：\(store.sourceStatusText)
        - 最近成功更新：\(store.lastRefreshText)
        - 最近读取尝试：\(store.lastAttemptText)
        - 本地历史大小：\(store.historyDatabaseSizeText)
        """
    case .zhHant:
        return """
        請幫我給 Quota Capsule 作者 Bono MA 整理一份產品回饋。

        回饋目標：
        - \(feedbackIssueTargetLine(for: store))
        - Email：\(FeedbackDestinations.authorEmail)
        - 作者 X：\(FeedbackDestinations.authorXURL.absoluteString)

        請先向我確認問題現象、重現步驟、預期表現、實際表現、截圖或錄影是否可以附上。然後幫我整理成一份清楚的回饋。如果我同意公開提交，就優先幫我開啟或建立 GitHub Issue；如果不適合公開，就幫我起草 Email。

        安全邊界：
        - 不要讀取或傳送 token、cookie、session、prompt、程式碼內容、專案路徑、視窗標題、private repo 位址。
        - 只使用我明確提供的截圖、錄影、錯誤訊息和下面這段應用狀態。

        應用狀態：
        - 應用：\(store.appDisplayName)
        - 發布渠道：\(store.releaseChannel.rawValue)
        - 目前判斷：\(store.visibleStatusText)
        - 資料來源狀態：\(store.sourceStatusText)
        - 最近成功更新：\(store.lastRefreshText)
        - 最近讀取嘗試：\(store.lastAttemptText)
        - 本機歷史大小：\(store.historyDatabaseSizeText)
        """
    case .en:
        return """
        Help me prepare product feedback for Quota Capsule by Bono MA.

        Feedback targets:
        - \(feedbackIssueTargetLine(for: store))
        - Email: \(FeedbackDestinations.authorEmail)
        - Author X profile: \(FeedbackDestinations.authorXURL.absoluteString)

        First ask me for the symptom, reproduction steps, expected behavior, actual behavior, and whether I can attach screenshots or a recording. Then turn it into a clear report. If I agree to public submission, help me open or create a GitHub Issue first. If it should stay private, draft an email instead.

        Safety boundary:
        - Do not read or send tokens, cookies, sessions, prompts, code content, project paths, window titles, or private repository URLs.
        - Use only screenshots, recordings, error messages, and the app status that I explicitly provide.

        App status:
        - App: \(store.appDisplayName)
        - Release channel: \(store.releaseChannel.rawValue)
        - Current judgment: \(store.visibleStatusText)
        - Data source status: \(store.sourceStatusText)
        - Last successful update: \(store.lastRefreshText)
        - Last read attempt: \(store.lastAttemptText)
        - Local history size: \(store.historyDatabaseSizeText)
        """
    }
}

@MainActor
private func feedbackIssueTargetLine(for store: QuotaStore) -> String {
    if let githubIssuesURL = store.githubIssuesURL {
        return "GitHub Issues: \(githubIssuesURL.absoluteString)"
    }

    switch store.copy.locale {
    case .zhHans:
        return "GitHub Issues：当前开发版没有配置内部 Issue 地址，请优先起草邮件"
    case .zhHant:
        return "GitHub Issues：目前開發版沒有設定內部 Issue 位址，請優先起草 Email"
    case .en:
        return "GitHub Issues: no internal Issue URL is configured for this development build; draft an email first"
    }
}
