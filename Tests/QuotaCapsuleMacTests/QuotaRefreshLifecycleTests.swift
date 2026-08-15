@testable import QuotaCapsuleMac
import Foundation
import QuotaCapsuleCore
import Testing

@Suite("Quota refresh lifecycle")
struct QuotaRefreshLifecycleTests {
    @MainActor
    @Test("QuotaStore leaves loading when its fetch task stops responding")
    func storeWatchdogEndsLoading() async throws {
        let identifier = UUID().uuidString
        let suiteName = "quota-refresh-tests-\(identifier)"
        let supportName = "Quota Capsule Refresh Tests \(identifier)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let configuration = AppConfiguration(
            channel: .beta,
            displayName: "Quota Capsule Refresh Tests",
            bundleIdentifier: "com.bono.quota-capsule.refresh-tests",
            githubIssuesURL: nil,
            analyticsEndpointURL: nil,
            applicationSupportDirectoryName: supportName,
            userDefaultsKeyPrefix: suiteName
        )
        defaults.set(QuotaLocale.zhHans.rawValue, forKey: configuration.userDefaultsKey("selectedLocale"))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            if let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try? FileManager.default.removeItem(at: root.appendingPathComponent(supportName))
            }
        }

        let store = QuotaStore(
            configuration: configuration,
            userDefaults: defaults,
            refreshWatchdogSeconds: 0.05,
            quotaFetcher: { _ in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return AgentQuotaSnapshot(
                    provider: "codex",
                    sourceStatus: .ok,
                    fetchedAt: Date(),
                    weeklyWindow: QuotaWindow(
                        label: "weekly",
                        windowMinutes: 10_080,
                        usedPercent: 10,
                        remainingPercent: 90,
                        resetsAt: Date().addingTimeInterval(604_800)
                    ),
                    errorMessage: nil
                )
            }
        )

        #expect(store.isRefreshing)
        try await Task.sleep(nanoseconds: 120_000_000)
        #expect(!store.isRefreshing)
        #expect(store.lastErrorText == store.copy.refreshWatchdogTimeout)
        #expect(store.visibleStatusText != store.copy.loadingStatus)
    }

    @Test("a timed-out refresh releases the gate for the next attempt")
    func timeoutReleasesRefreshGate() {
        var lifecycle = QuotaRefreshLifecycle()
        let first = lifecycle.begin()

        #expect(first != nil)
        #expect(lifecycle.begin() == nil)
        let didExpire = lifecycle.expire(first!)
        #expect(didExpire)
        #expect(!lifecycle.isActive)
        #expect(lifecycle.begin() != nil)
    }

    @Test("a late result from an expired attempt cannot finish the replacement")
    func lateResultCannotFinishReplacement() {
        var lifecycle = QuotaRefreshLifecycle()
        let first = lifecycle.begin()!
        let didExpire = lifecycle.expire(first)
        #expect(didExpire)
        let replacement = lifecycle.begin()!

        let didFinishExpiredAttempt = lifecycle.finish(first)
        #expect(!didFinishExpiredAttempt)
        #expect(lifecycle.isActive)
        let didFinishReplacement = lifecycle.finish(replacement)
        #expect(didFinishReplacement)
        #expect(!lifecycle.isActive)
    }

    @Test("the watchdog outlives expected retries but ends in under a minute")
    func watchdogBoundsTheUserWait() {
        #expect(QuotaRefreshPolicy.watchdogSeconds > QuotaRefreshPolicy.maximumExpectedFetchSeconds)
        #expect(QuotaRefreshPolicy.watchdogSeconds < 60)
    }

    @Test("the timeout explanation is actionable in every language")
    func timeoutCopyIsActionable() {
        for locale in [QuotaLocale.zhHans, .zhHant, .en] {
            let message = QuotaCopy(locale: locale).refreshWatchdogTimeout
            #expect(message.contains("30"))
            #expect(!message.isEmpty)
        }
    }
}
