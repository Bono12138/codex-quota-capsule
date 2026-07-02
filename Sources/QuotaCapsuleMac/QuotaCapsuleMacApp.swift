import SwiftUI
import AppKit
import QuotaCapsuleCore

@main
struct QuotaCapsuleMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                store: appDelegate.store,
                onTogglePanel: appDelegate.togglePanel,
                onShowAboutFeedback: appDelegate.showAboutFeedback,
                onShowContactAuthor: appDelegate.showContactAuthor,
                onShowAdvancedDataSettings: appDelegate.showAdvancedDataSettings,
                onShowOnboarding: appDelegate.showOnboarding,
                onConfirmRevokeAnalytics: appDelegate.confirmRevokeAnalytics,
                onConfirmClearLocalHistory: appDelegate.confirmClearLocalHistory
            )
        } label: {
            MenuBarLabel(store: appDelegate.store)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            AdvancedDataSettingsView(
                store: appDelegate.store,
                context: "settings",
                onConfirmRevokeAnalytics: appDelegate.confirmRevokeAnalytics,
                onConfirmClearLocalHistory: appDelegate.confirmClearLocalHistory
            )
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = QuotaStore()
    private var panelController: CapsulePanelController?
    private var aboutFeedbackWindow: NSWindow?
    private var contactAuthorWindow: NSWindow?
    private var advancedDataSettingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        attach(store: store)
        if !store.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.showOnboarding()
            }
        }
    }

    func attach(store: QuotaStore) {
        if panelController == nil {
            panelController = CapsulePanelController(store: store)
        }
        panelController?.show()
    }

    func togglePanel() {
        panelController?.toggle()
    }

    func showPanel() {
        panelController?.show()
    }

    func showAboutFeedback() {
        store.recordFeedbackWindowOpened()
        if let aboutFeedbackWindow {
            aboutFeedbackWindow.title = store.copy.aboutFeedbackTitle
            aboutFeedbackWindow.contentViewController = NSHostingController(rootView: AboutFeedbackView(store: store))
            present(window: aboutFeedbackWindow)
            return
        }

        let window = makeWindow(title: store.copy.aboutFeedbackTitle, size: NSSize(width: 760, height: 640))
        window.contentViewController = NSHostingController(rootView: AboutFeedbackView(store: store))
        aboutFeedbackWindow = window
        present(window: window)
    }

    func showContactAuthor() {
        store.recordFeedbackWindowOpened()
        if let contactAuthorWindow {
            contactAuthorWindow.title = store.copy.contactAuthorTitle
            contactAuthorWindow.contentViewController = NSHostingController(rootView: ContactAuthorView(store: store, context: "contact"))
            present(window: contactAuthorWindow)
            return
        }

        let window = makeWindow(title: store.copy.contactAuthorTitle, size: NSSize(width: 760, height: 560))
        window.contentViewController = NSHostingController(rootView: ContactAuthorView(store: store, context: "contact"))
        contactAuthorWindow = window
        present(window: window)
    }

    func showAdvancedDataSettings() {
        if let advancedDataSettingsWindow {
            advancedDataSettingsWindow.title = store.copy.advancedDataSettingsTitle
            advancedDataSettingsWindow.contentViewController = NSHostingController(
                rootView: AdvancedDataSettingsView(
                    store: store,
                    context: "advanced_data_settings",
                    onConfirmRevokeAnalytics: confirmRevokeAnalytics,
                    onConfirmClearLocalHistory: confirmClearLocalHistory
                )
            )
            present(window: advancedDataSettingsWindow)
            return
        }

        let window = makeWindow(title: store.copy.advancedDataSettingsTitle, size: NSSize(width: 640, height: 460))
        window.contentViewController = NSHostingController(
            rootView: AdvancedDataSettingsView(
                store: store,
                context: "advanced_data_settings",
                onConfirmRevokeAnalytics: confirmRevokeAnalytics,
                onConfirmClearLocalHistory: confirmClearLocalHistory
            )
        )
        advancedDataSettingsWindow = window
        present(window: window)
    }

    func confirmRevokeAnalytics() {
        guard confirmDestructiveAction(
            title: store.copy.confirmRevokeAnalyticsTitle,
            message: store.copy.confirmRevokeAnalyticsMessage,
            confirmTitle: store.copy.analyticsRevokeAction,
            cancelTitle: store.copy.keepParticipatingAction
        ) else {
            return
        }
        store.setAnalyticsConsent(.denied)
    }

    func confirmClearLocalHistory() {
        guard confirmDestructiveAction(
            title: store.copy.confirmClearLocalHistoryTitle,
            message: store.copy.confirmClearLocalHistoryMessage,
            confirmTitle: store.copy.clearLocalHistoryAction,
            cancelTitle: store.copy.keepLocalHistoryAction
        ) else {
            return
        }
        store.clearLocalHistory()
    }

    func showOnboarding() {
        if let onboardingWindow {
            panelController?.setExpanded(true)
            present(window: onboardingWindow)
            return
        }

        panelController?.setExpanded(true)
        let window = makeWindow(title: store.copy.userGuideAction, size: NSSize(width: 680, height: 740))
        window.contentViewController = NSHostingController(
            rootView: OnboardingView(store: store) { [weak self] in
                self?.onboardingWindow?.close()
            }
        )
        onboardingWindow = window
        present(window: window)
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.trackAppQuit()
    }

    private func makeWindow(title: String, size: NSSize = NSSize(width: 560, height: 560)) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: min(size.width, 520), height: min(size.height, 520))
        if let visible = NSScreen.currentPlacementScreen?.visibleFrame {
            window.setFrameOrigin(
                NSPoint(
                    x: visible.midX - window.frame.width / 2,
                    y: visible.midY - window.frame.height / 2
                )
            )
        } else {
            window.center()
        }
        return window
    }

    private func present(window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func confirmDestructiveAction(
        title: String,
        message: String,
        confirmTitle: String,
        cancelTitle: String
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: cancelTitle)
        alert.addButton(withTitle: confirmTitle)
        return alert.runModal() == .alertSecondButtonReturn
    }
}
