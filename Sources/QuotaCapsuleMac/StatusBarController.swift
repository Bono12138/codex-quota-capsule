import AppKit
import Combine

@MainActor
final class StatusBarController {
    private let store: QuotaStore
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []

    var onTogglePanel: (() -> Void)?
    var onShowAboutFeedback: (() -> Void)?
    var onShowContactAuthor: (() -> Void)?
    var onShowAdvancedDataSettings: (() -> Void)?
    var onShowOnboarding: (() -> Void)?
    var onConfirmRevokeAnalytics: (() -> Void)?
    var onConfirmClearLocalHistory: (() -> Void)?

    init(store: QuotaStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        rebuildMenu()

        store.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.configureButton()
                    self?.rebuildMenu()
                }
            }
            .store(in: &cancellables)
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "Quota Capsule")
        button.imagePosition = .imageLeading
        button.title = statusBarTitle
        button.toolTip = "Quota Capsule · \(store.visibleStatusText)"
    }

    private var statusBarTitle: String {
        if let used = store.compactUsedPercent {
            return " \(store.visibleStatusText) \(used)%"
        }
        return " \(store.visibleStatusText)"
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let header = NSMenuItem(title: store.visibleMenuBarText, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(actionItem(store.copy.refreshNowAction) { [weak self] in
            self?.store.refresh()
        })
        menu.addItem(actionItem(store.copy.toggleCapsuleAction) { [weak self] in
            self?.onTogglePanel?()
        })
        menu.addItem(actionItem(store.copy.userGuideAction) { [weak self] in
            self?.onShowOnboarding?()
        })

        menu.addItem(languageMenuItem())
        menu.addItem(.separator())
        menu.addItem(contactMenuItem())
        menu.addItem(actionItem(store.copy.aboutFeedbackTitle) { [weak self] in
            self?.onShowAboutFeedback?()
        })
        menu.addItem(advancedDataSettingsMenuItem())

        if let githubIssuesURL = store.githubIssuesURL {
            menu.addItem(actionItem(store.copy.githubIssuesAction) { [weak self] in
                self?.store.recordFeedbackClick("github")
                NSWorkspace.shared.open(githubIssuesURL)
            })
        }

        menu.addItem(actionItem(store.copy.codexFeedbackAction) { [weak self] in
            guard let self else { return }
            let destination = startAssistedFeedback(store: self.store)
            self.showAssistedFeedbackAlert(destination: destination)
        })

        menu.addItem(.separator())
        menu.addItem(actionItem(store.copy.quitAction) {
            NSApp.terminate(nil)
        })

        statusItem.menu = menu
    }

    private func languageMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: store.copy.languageMenuTitle, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.addItem(actionItem("简体中文 · \(store.copy.languageSimplifiedAssistiveLabel)") { [weak self] in
            self?.store.selectLocale(.zhHans)
        })
        submenu.addItem(actionItem("繁體中文 · \(store.copy.languageTraditionalAssistiveLabel)") { [weak self] in
            self?.store.selectLocale(.zhHant)
        })
        submenu.addItem(actionItem("English · \(store.copy.languageEnglishAssistiveLabel)") { [weak self] in
            self?.store.selectLocale(.en)
        })
        item.submenu = submenu
        return item
    }

    private func contactMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: store.copy.contactAuthorTitle, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        [store.copy.authorLine, store.copy.emailLine, store.copy.xLine, store.copy.douyinLine].forEach { line in
            let lineItem = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            lineItem.isEnabled = false
            submenu.addItem(lineItem)
        }
        submenu.addItem(.separator())
        submenu.addItem(actionItem(store.copy.emailFeedbackAction) { [weak self] in
            self?.store.recordFeedbackClick("email")
            NSWorkspace.shared.open(URL(string: "mailto:\(FeedbackDestinations.authorEmail)")!)
        })
        submenu.addItem(actionItem(store.copy.openXAction) { [weak self] in
            self?.store.recordFeedbackClick("x")
            NSWorkspace.shared.open(FeedbackDestinations.authorXURL)
        })
        submenu.addItem(actionItem(store.copy.openDouyinAction) { [weak self] in
            self?.store.recordFeedbackClick("douyin_open")
            NSWorkspace.shared.open(FeedbackDestinations.douyinURL)
        })
        submenu.addItem(actionItem(store.copy.contactAuthorTitle) { [weak self] in
            self?.onShowContactAuthor?()
        })
        item.submenu = submenu
        return item
    }

    private func advancedDataSettingsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: store.copy.advancedDataSettingsTitle, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let privacyItem = NSMenuItem(title: store.copy.localDataPrivacyAuthorizationTitle, action: nil, keyEquivalent: "")
        let privacySubmenu = NSMenu()
        privacySubmenu.addItem(actionItem(store.copy.analyticsRevokeAction) { [weak self] in
            self?.onConfirmRevokeAnalytics?()
        })
        privacySubmenu.addItem(actionItem(store.copy.clearLocalHistoryAction) { [weak self] in
            self?.onConfirmClearLocalHistory?()
        })
        privacyItem.submenu = privacySubmenu
        submenu.addItem(privacyItem)

        submenu.addItem(actionItem(store.copy.advancedDataSettingsTitle) { [weak self] in
            self?.onShowAdvancedDataSettings?()
        })
        item.submenu = submenu
        return item
    }

    private func actionItem(_ title: String, action: @escaping () -> Void) -> NSMenuItem {
        ClosureMenuItem(title: title, actionHandler: action)
    }

    private func showAssistedFeedbackAlert(destination: AssistedFeedbackDestination) {
        let alert = NSAlert()
        alert.messageText = store.copy.codexFeedbackCopiedAction
        alert.informativeText = destination == .github ? store.copy.assistedFeedbackStartedMessage : store.copy.assistedFeedbackEmailMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: store.copy.doneAction)
        alert.runModal()
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let actionHandler: () -> Void

    init(title: String, actionHandler: @escaping () -> Void) {
        self.actionHandler = actionHandler
        super.init(title: title, action: #selector(runAction), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func runAction() {
        actionHandler()
    }
}
