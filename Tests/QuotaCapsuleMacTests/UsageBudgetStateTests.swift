import Foundation
import Testing
import QuotaCapsuleCore
@testable import QuotaCapsuleMac

@Suite("Local budget persistence")
@MainActor
struct UsageBudgetStateTests {
    @Test func defaultNeedsNoSetupAndHandlesAnOvernightDeadline() throws {
        let name = "budget-default-tests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let state = UsageBudgetState(defaults: defaults, prefix: "test")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func update(_ timestamp: String) {
            let now = ISO8601DateFormatter().date(from: timestamp)!
            state.update(snapshot: AgentQuotaSnapshot(provider: "codex", sourceStatus: .ok, fetchedAt: now,
                weeklyWindow: QuotaWindow(label: "weekly", windowMinutes: 10080, usedPercent: 40,
                    remainingPercent: 60, resetsAt: now.addingTimeInterval(3600)), errorMessage: nil),
                confirming: false, now: now, calendar: calendar)
        }
        update("2026-09-20T12:00:00Z")
        #expect(state.result.allowance == 60)
        #expect(!state.usesDeadlineFallback)
        let reopened = UsageBudgetState(defaults: defaults, prefix: "test")
        #expect(reopened.usesDefaultPlan)
        #expect(reopened.anchor == state.anchor)
        state.restoreDefault()
        update("2026-09-20T01:00:00Z")
        #expect(state.result.allowance == 60)
        #expect(state.usesDeadlineFallback)
        state.save(UsagePlan(startHour: 18, endHour: 22))
        update("2026-09-20T01:00:00Z")
        #expect(state.result.state == .noSession)
        state.restoreDefault()
        let restored = UsageBudgetState(defaults: defaults, prefix: "test")
        #expect(restored.usesDefaultPlan)
        #expect(restored.plan == UsagePlan())
    }

    @Test func fiveHourExhaustionOverridesWeeklyAllowance() async throws {
        let name = "budget-priority-tests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        let configuration = AppConfiguration(channel: .beta, displayName: name,
            bundleIdentifier: "com.bono.quota-capsule.budget-tests", githubIssuesURL: nil,
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
                fiveHourWindow: QuotaWindow(label: "five_hour", windowMinutes: 300,
                    usedPercent: 100, remainingPercent: 0, resetsAt: now.addingTimeInterval(3600)),
                weeklyWindow: QuotaWindow(label: "weekly", windowMinutes: 10080,
                    usedPercent: 20, remainingPercent: 80, resetsAt: now.addingTimeInterval(86400 * 3)),
                errorMessage: nil)
        })
        for _ in 0..<40 {
            if !store.isRefreshing { break }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        store.saveUsagePlan(UsagePlan(startHour: 0, endHour: 0))
        #expect(store.snapshot.fiveHourWindow?.remainingPercent == 0)
        let allowance = try #require(store.usageBudgetState.result.allowance)
        #expect(allowance > 0)
        #expect(store.budgetTone == .danger)
        #expect(store.visibleStatusText.contains("5"))
    }

    @Test func restartStaleAndConfirmation() throws {
        let name = "budget-tests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let state = UsageBudgetState(defaults: defaults, prefix: "test")
        #expect(state.plan == UsagePlan())
        #expect(state.usesDefaultPlan)
        let now = Date()
        let reset = now.addingTimeInterval(86400 * 3)
        func snapshot(_ remaining: Double, _ time: Date) -> AgentQuotaSnapshot {
            AgentQuotaSnapshot(provider: "codex", sourceStatus: .ok, fetchedAt: time,
                weeklyWindow: QuotaWindow(label: "weekly", windowMinutes: 10080,
                    usedPercent: 100 - remaining, remainingPercent: remaining, resetsAt: reset), errorMessage: nil)
        }
        state.save(UsagePlan(startHour: 0, endHour: 0))
        #expect(!state.usesDefaultPlan)
        state.update(snapshot: snapshot(60, now), confirming: false, now: now)
        let anchor = try #require(state.anchor)
        let restored = UsageBudgetState(defaults: defaults, prefix: "test")
        #expect(restored.anchor == anchor)
        #expect(!restored.usesDefaultPlan)
        restored.update(snapshot: snapshot(55, now), confirming: true, now: now)
        #expect(restored.result.state == .unavailable)
        #expect(restored.anchor == anchor)
        restored.update(snapshot: snapshot(55, now), confirming: false, now: now.addingTimeInterval(181))
        #expect(restored.result.state == .unavailable)
        restored.update(snapshot: snapshot(55, now), confirming: false, now: now)
        #expect(restored.result.allowance == max(0, anchor.allocation - 5))
        restored.save(UsagePlan(startHour: 0, endHour: 0, reservePercent: 20))
        #expect(restored.anchor == nil)
    }

    @Test func failedSourceSuspendsBudget() throws {
        let name = "budget-credit-tests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let state = UsageBudgetState(defaults: defaults, prefix: "test")
        state.save(UsagePlan(startHour: 0, endHour: 0))
        let now = Date()
        let snapshot = AgentQuotaSnapshot(provider: "codex", sourceStatus: .error, fetchedAt: now,
            weeklyWindow: nil, errorMessage: "unavailable")
        state.update(snapshot: snapshot, confirming: false, now: now)
        #expect(state.result.allowance == nil)
        #expect(state.result.state == .unavailable)
    }

    @Test func sessionAndCreditDeadlineRequireFreshReading() throws {
        let name = "budget-boundary-tests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let state = UsageBudgetState(defaults: defaults, prefix: "test")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = ISO8601DateFormatter().date(from: "2026-09-20T18:00:00Z")!
        let expiry = start.addingTimeInterval(60)
        let reset = start.addingTimeInterval(86400 * 3)
        func snapshot(_ time: Date, remaining: Double = 60) -> AgentQuotaSnapshot {
            AgentQuotaSnapshot(provider: "codex", sourceStatus: .ok, fetchedAt: time,
                weeklyWindow: QuotaWindow(label: "weekly", windowMinutes: 10080,
                    usedPercent: 100 - remaining, remainingPercent: remaining, resetsAt: reset),
                resetCreditBank: ResetCreditBankSummary(availableCount: 1, credits: [
                    ResetCredit(fingerprint: "synthetic", resetType: "codexRateLimits", status: .available,
                        grantedAt: nil, grantTimeSource: .unknown, expiresAt: expiry, title: "Full reset")
                ], detailState: .complete, fetchedAt: time), errorMessage: nil)
        }
        state.save(UsagePlan(startHour: 18, endHour: 22))
        state.update(snapshot: snapshot(start.addingTimeInterval(-30)), confirming: false, now: start, calendar: calendar)
        #expect(state.result.state == .unavailable)
        state.update(snapshot: snapshot(start), confirming: false, now: start, calendar: calendar)
        #expect(state.result.allowance == 60)
        state.update(snapshot: snapshot(start), confirming: false, now: expiry, calendar: calendar)
        #expect(state.result.state == .unavailable)
        state.update(snapshot: snapshot(expiry, remaining: 55), confirming: false, now: expiry, calendar: calendar)
        #expect(state.anchor?.initialRemaining == 55)
        #expect(state.anchor?.horizon == reset)
        #expect(state.result.allowance! < 55)
    }
}
