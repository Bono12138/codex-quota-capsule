import SwiftUI
import AppKit
import QuotaCapsuleCore

@main
struct QuotaCapsuleMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(store: appDelegate.store)
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        attach(store: store)
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
}
