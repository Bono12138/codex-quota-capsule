import QuotaCapsuleCore

struct StatusBarUpdateGate<Value: Equatable> {
    private(set) var applied: Value?
    private var pending: Value?
    private var isTracking = false

    mutating func receive(_ value: Value) -> Value? {
        if isTracking {
            if value == applied {
                pending = nil
                return nil
            }
            if value == pending { return nil }
            pending = value
            return nil
        }
        guard value != applied else { return nil }
        applied = value
        return value
    }

    mutating func beginTracking() {
        isTracking = true
    }

    mutating func endTracking() -> Value? {
        guard isTracking else { return nil }
        isTracking = false
        guard let pending else { return nil }
        self.pending = nil
        applied = pending
        return pending
    }
}

struct StatusBarPresentation: Equatable {
    let buttonTitle: String
    let toolTip: String
    let headerTitle: String
    let refreshTitle: String
    let toggleTitle: String
    let userGuideTitle: String
    let languageMenuTitle: String
    let languageTitles: [String]
    let contactAuthorTitle: String
    let contactLines: [String]
    let emailFeedbackTitle: String
    let openXTitle: String
    let openDouyinTitle: String
    let aboutFeedbackTitle: String
    let submitFeedbackTitle: String
    let quitTitle: String

    static func make(
        copy: QuotaCopy,
        statusText: String,
        menuBarText: String,
        compactUsedValueText: String?
    ) -> StatusBarPresentation {
        let toolTip = compactUsedValueText.map { "Quota Capsule · \(statusText) · \($0)" }
            ?? "Quota Capsule · \(statusText)"
        return StatusBarPresentation(
            buttonTitle: " \(menuBarText)",
            toolTip: toolTip,
            headerTitle: menuBarText,
            refreshTitle: copy.refreshNowAction,
            toggleTitle: copy.toggleCapsuleAction,
            userGuideTitle: copy.userGuideAction,
            languageMenuTitle: copy.languageMenuTitle,
            languageTitles: [
                "简体中文 · \(copy.languageSimplifiedAssistiveLabel)",
                "繁體中文 · \(copy.languageTraditionalAssistiveLabel)",
                "English · \(copy.languageEnglishAssistiveLabel)"
            ],
            contactAuthorTitle: copy.contactAuthorTitle,
            contactLines: [copy.authorLine, copy.emailLine, copy.xLine, copy.douyinLine],
            emailFeedbackTitle: copy.emailFeedbackAction,
            openXTitle: copy.openXAction,
            openDouyinTitle: copy.openDouyinAction,
            aboutFeedbackTitle: copy.aboutFeedbackTitle,
            submitFeedbackTitle: copy.submitFeedbackAction,
            quitTitle: copy.quitAction
        )
    }
}
