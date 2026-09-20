import AppKit
import SwiftUI
import Testing
import QuotaCapsuleCore
@testable import QuotaCapsuleMac

@Suite("Dual progress presentation")
@MainActor
struct ProgressComparisonTests {
    @Test func tinyCapsulesHaveBoundedFootprints() {
        #expect(CapsuleViewMetrics.collapsedContentHeight == 44)
        #expect(CapsuleViewMetrics.dockedContentHeight == 32)
        #expect(CapsuleViewMetrics.dockedContentWidth == 110)
    }

    @Test func renderCompactAndDockedFootprints() async throws {
        _ = NSApplication.shared
        let name = "compact-render-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        let configuration = AppConfiguration(channel: .beta, displayName: name,
            bundleIdentifier: "com.bono.quota-capsule.render-tests", githubIssuesURL: nil,
            analyticsEndpointURL: nil, applicationSupportDirectoryName: name, userDefaultsKeyPrefix: name)
        defer {
            defaults.removePersistentDomain(forName: name)
            if let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try? FileManager.default.removeItem(at: root.appendingPathComponent(name))
            }
        }
        let store = QuotaStore(configuration: configuration, userDefaults: defaults, quotaFetcher: { _ in
            let now = Date()
            return AgentQuotaSnapshot(provider: "codex", sourceStatus: .ok, fetchedAt: now,
                weeklyWindow: QuotaWindow(label: "weekly", windowMinutes: 10080, usedPercent: 8,
                    remainingPercent: 92, resetsAt: now.addingTimeInterval(3 * 86400)), errorMessage: nil)
        })
        for _ in 0..<40 {
            if !store.isRefreshing { break }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        store.saveUsagePlan(UsagePlan(startHour: 0, endHour: 0))
        #expect(store.capsuleWidth == 180)
        #expect(store.capsuleContentWidth == 180)
        store.setPanelExpanded(true)
        #expect(store.capsuleContentWidth == 340)
        store.setPanelExpanded(false)
        #expect(store.capsuleContentWidth == 180)
        store.setCapsuleDocked(true)
        #expect(store.capsuleContentWidth == 110)
        store.setCapsuleDocked(false)
        #expect(store.capsuleHoverText.contains(store.primaryHorizonText))
        #expect(store.capsuleHoverText.contains("8%"))
        #expect(!store.friendlyPaceText.contains("92"))
        #expect(!store.visibleStatusText.contains("默认预算"))
        guard let directory = ProcessInfo.processInfo.environment["QUOTA_RENDER_DIRECTORY"] else { return }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for locale in [QuotaLocale.zhHans, .zhHant, .en] {
            store.selectLocale(locale)
            for width in [180.0, 200.0, 220.0] {
                store.setCapsuleWidth(width, commit: false)
                let view = VStack(spacing: 20) {
                    CompactCapsuleView(store: store)
                    DockedCapsuleView(store: store)
                }.padding(20).background(Color.white).environment(\.colorScheme, .light)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = try #require(renderer.nsImage)
                #expect(image.size.height == 136)
                let tiff = try #require(image.tiffRepresentation)
                let bitmap = try #require(NSBitmapImageRep(data: tiff))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("compact-\(locale.rawValue)-\(Int(width)).png"))
            }
        }
    }
    @Test func limitingWindowAndMissingDataOverrideHumor() {
        #expect(PaceMessage.classify(used: 20, available: 70, active: true, fiveHourRemaining: 5) == .fiveHour)
        #expect(PaceMessage.classify(used: 95, available: 70, active: true, fiveHourRemaining: 80) == .low)
        #expect(PaceMessage.classify(used: 20, available: 70, active: false, fiveHourRemaining: 80) == .resting)
        #expect(PaceMessage.classify(used: 20, available: 70, active: true, fiveHourRemaining: 80) == .abundant)
        #expect(PaceMessage.classify(used: 70, available: 20, active: true, fiveHourRemaining: nil) == .fast)
        #expect(PaceMessage.classify(used: 25, available: 30, active: true, fiveHourRemaining: nil) == .balanced)
        #expect(PaceMessage.classify(used: .nan, available: 30, active: true, fiveHourRemaining: nil) == nil)
        #expect(PaceMessage.classify(used: 25, available: nil, active: true, fiveHourRemaining: nil) == nil)
    }
    @Test func messagesAreStableLocalizedAndVaried() {
        for locale in [QuotaLocale.zhHans, .zhHant, .en] {
            let copy = BudgetCopy(locale: locale)
            for message in PaceMessage.allCases {
                #expect(message.text(copy: copy, seed: 123) == message.text(copy: copy, seed: 123))
                #expect(!message.text(copy: copy, seed: -1).isEmpty)
                if message != .fiveHour {
                    #expect(Set((0..<3).map { message.text(copy: copy, seed: $0) }).count == 3)
                }
            }
        }
    }

    @Test func renderClockOrderAndUnknownStates() throws {
        guard let directory = ProcessInfo.processInfo.environment["QUOTA_RENDER_DIRECTORY"] else { return }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for locale in [QuotaLocale.zhHans, .zhHant, .en] {
            for scheme in [ColorScheme.light, .dark] {
                let view = HStack(alignment: .top, spacing: 20) {
                    ForEach([266.0, 346.0, 486.0], id: \.self) { width in
                        VStack(spacing: 24) {
                            ProgressComparisonView(natural: 40, available: 60, used: 25, copy: BudgetCopy(locale: locale), compact: true)
                            ProgressComparisonView(natural: 65, available: 40, used: 90, copy: BudgetCopy(locale: locale))
                            ProgressComparisonView(natural: 100, available: 100, used: 100, copy: BudgetCopy(locale: locale))
                            ProgressComparisonView(natural: nil, available: nil, used: nil, copy: BudgetCopy(locale: locale))
                        }.frame(width: width)
                    }
                }.padding(20).background(scheme == .light ? Color.white : Color.black)
                    .environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = try #require(renderer.nsImage)
                let tiff = try #require(image.tiffRepresentation)
                let bitmap = try #require(NSBitmapImageRep(data: tiff))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("dual-\(locale.rawValue)-\(scheme).png"))
            }
        }
    }
}
