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
                onShowOnboarding: appDelegate.showOnboarding
            )
        } label: {
            MenuBarLabel(store: appDelegate.store)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(store: appDelegate.store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = QuotaStore()
    private var panelController: CapsulePanelController?
    private var aboutFeedbackWindow: NSWindow?
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
        if let aboutFeedbackWindow {
            present(window: aboutFeedbackWindow)
            return
        }

        let window = makeWindow(title: store.copy.aboutFeedbackTitle)
        window.contentViewController = NSHostingController(rootView: SettingsView(store: store))
        aboutFeedbackWindow = window
        present(window: window)
    }

    func showOnboarding() {
        if let onboardingWindow {
            present(window: onboardingWindow)
            return
        }

        let window = makeWindow(title: store.copy.userGuideAction)
        window.contentViewController = NSHostingController(
            rootView: OnboardingView(store: store) { [weak self] in
                self?.store.completeOnboarding()
                self?.onboardingWindow?.close()
            }
        )
        onboardingWindow = window
        present(window: window)
    }

    private func makeWindow(title: String) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
