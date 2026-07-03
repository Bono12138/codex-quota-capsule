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
    var onShowOnboarding: (() -> Void)?
    var onConfirmRevokeAnalytics: (() -> Void)?
    var onConfirmClearLocalHistory: (() -> Void)?

    init(store: QuotaStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
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
            NSLog("Quota Capsule status item button is unavailable")
            return
        }

        button.image = makeStatusIcon()
        button.imagePosition = .imageLeading
        button.title = " \(statusBarTitle)"
        button.toolTip = "Quota Capsule · \(statusBarTooltip)"
        button.appearsDisabled = false
    }

    func showMenu() {
        rebuildMenu()
        guard let menu = statusItem.menu else {
            return
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private var statusBarTitle: String {
        if let used = store.compactUsedPercent {
            return "\(store.visibleStatusText) \(used)%"
        }
        return store.visibleStatusText
    }

    private var statusBarTooltip: String {
        if let used = store.compactUsedPercent {
            return "\(store.visibleStatusText) · \(used)%"
        }
        return store.visibleStatusText
    }

    private func makeStatusIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.black.setFill()
        let bodyRect = NSRect(x: 2.4, y: 5.1, width: 13.2, height: 7.8)
        NSBezierPath(roundedRect: bodyRect, xRadius: 3.9, yRadius: 3.9).fill()

        NSColor.clear.setFill()
        NSBezierPath(ovalIn: NSRect(x: 5.2, y: 7.2, width: 3.4, height: 3.4)).fill()
        NSBezierPath(ovalIn: NSRect(x: 10.1, y: 7.2, width: 3.4, height: 3.4)).fill()

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "Quota Capsule"
        return image
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

        menu.addItem(actionItem(store.copy.submitFeedbackAction) { [weak self] in
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
