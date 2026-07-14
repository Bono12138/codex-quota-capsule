import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let store: QuotaStore
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []
    private var updateGate = StatusBarUpdateGate<StatusBarPresentation>()

    var onTogglePanel: (() -> Void)?
    var onShowAboutFeedback: (() -> Void)?
    var onShowContactAuthor: (() -> Void)?
    var onShowOnboarding: (() -> Void)?
    var onConfirmRevokeAnalytics: (() -> Void)?
    var onConfirmClearLocalHistory: (() -> Void)?

    init(store: QuotaStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.isVisible = true

        store.$statusBarPresentation
            .removeDuplicates()
            .sink { [weak self] presentation in
                self?.receive(presentation)
            }
            .store(in: &cancellables)
    }

    private func receive(_ presentation: StatusBarPresentation) {
        guard let next = updateGate.receive(presentation) else { return }
        apply(next)
    }

    private func apply(_ presentation: StatusBarPresentation) {
        configureButton(presentation)
        rebuildMenu(presentation)
    }

    private func configureButton(_ presentation: StatusBarPresentation) {
        guard let button = statusItem.button else {
            NSLog("Quota Capsule status item button is unavailable")
            return
        }

        button.image = makeStatusIcon()
        button.imagePosition = .imageLeading
        button.title = presentation.buttonTitle
        button.toolTip = presentation.toolTip
        button.appearsDisabled = false
    }

    func showMenu() {
        guard let menu = statusItem.menu else {
            return
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
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

    private func rebuildMenu(_ presentation: StatusBarPresentation) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let header = NSMenuItem(title: presentation.headerTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(actionItem(presentation.refreshTitle) { [weak self] in
            self?.store.refresh()
        })
        menu.addItem(actionItem(presentation.toggleTitle) { [weak self] in
            self?.onTogglePanel?()
        })
        menu.addItem(actionItem(presentation.userGuideTitle) { [weak self] in
            self?.onShowOnboarding?()
        })

        menu.addItem(languageMenuItem(presentation))
        menu.addItem(.separator())
        menu.addItem(contactMenuItem(presentation))
        menu.addItem(actionItem(presentation.aboutFeedbackTitle) { [weak self] in
            self?.onShowAboutFeedback?()
        })

        menu.addItem(actionItem(presentation.submitFeedbackTitle) { [weak self] in
            guard let self else { return }
            let destination = startAssistedFeedback(store: self.store)
            self.showAssistedFeedbackAlert(destination: destination)
        })

        menu.addItem(.separator())
        menu.addItem(actionItem(presentation.quitTitle) {
            NSApp.terminate(nil)
        })

        statusItem.menu = menu
    }

    private func languageMenuItem(_ presentation: StatusBarPresentation) -> NSMenuItem {
        let item = NSMenuItem(title: presentation.languageMenuTitle, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.addItem(actionItem(presentation.languageTitles[0]) { [weak self] in
            self?.store.selectLocale(.zhHans)
        })
        submenu.addItem(actionItem(presentation.languageTitles[1]) { [weak self] in
            self?.store.selectLocale(.zhHant)
        })
        submenu.addItem(actionItem(presentation.languageTitles[2]) { [weak self] in
            self?.store.selectLocale(.en)
        })
        item.submenu = submenu
        return item
    }

    private func contactMenuItem(_ presentation: StatusBarPresentation) -> NSMenuItem {
        let item = NSMenuItem(title: presentation.contactAuthorTitle, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        presentation.contactLines.forEach { line in
            let lineItem = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            lineItem.isEnabled = false
            submenu.addItem(lineItem)
        }
        submenu.addItem(.separator())
        submenu.addItem(actionItem(presentation.emailFeedbackTitle) { [weak self] in
            self?.store.recordFeedbackClick("email")
            NSWorkspace.shared.open(URL(string: "mailto:\(FeedbackDestinations.authorEmail)")!)
        })
        submenu.addItem(actionItem(presentation.openXTitle) { [weak self] in
            self?.store.recordFeedbackClick("x")
            NSWorkspace.shared.open(FeedbackDestinations.authorXURL)
        })
        submenu.addItem(actionItem(presentation.openDouyinTitle) { [weak self] in
            self?.store.recordFeedbackClick("douyin_open")
            NSWorkspace.shared.open(FeedbackDestinations.douyinURL)
        })
        submenu.addItem(actionItem(presentation.contactAuthorTitle) { [weak self] in
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

    func menuWillOpen(_ menu: NSMenu) {
        updateGate.beginTracking()
    }

    func menuDidClose(_ menu: NSMenu) {
        guard let next = updateGate.endTracking() else { return }
        apply(next)
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
