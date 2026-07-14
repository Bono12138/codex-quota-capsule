@testable import QuotaCapsuleMac
import Foundation
import QuotaCapsuleCore
import SQLite3
import Testing

@Suite("Reset credit persistence")
struct ResetCreditPersistenceTests {
    @MainActor
    @Test("complete bank samples coalesce and expiry is classified locally")
    func bankHistoryCoalescesAndExpires() throws {
        let context = try TestStoreContext()
        defer { context.cleanup() }
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let expiry = now.addingTimeInterval(100)
        let credit = ResetCredit(
            fingerprint: String(repeating: "a", count: 64),
            resetType: "codexRateLimits",
            status: .available,
            grantedAt: now.addingTimeInterval(-86_400),
            grantTimeSource: .provider,
            expiresAt: expiry,
            title: "Full reset"
        )
        let bank = ResetCreditBankSummary(
            availableCount: 1,
            credits: [credit],
            detailState: .complete,
            fetchedAt: now
        )

        context.store.recordResetCreditBank(bank)
        context.store.recordResetCreditBank(ResetCreditBankSummary(
            availableCount: 1,
            credits: [credit],
            detailState: .complete,
            fetchedAt: now.addingTimeInterval(60)
        ))
        context.store.recordResetCreditBank(ResetCreditBankSummary(
            availableCount: 0,
            credits: [],
            detailState: .complete,
            fetchedAt: expiry.addingTimeInterval(1)
        ))

        let history = context.store.resetCreditHistory()
        #expect(history.count == 1)
        #expect(history[0].sampleCount == 2)
        #expect(history[0].lifecycle == .expired)
        let runs = context.store.resetCreditBankRuns()
        #expect(runs.count == 2)
        #expect(runs[0].sampleCount == 2)

        context.store.clearAll()
        #expect(context.store.resetCreditHistory().isEmpty)
        #expect(context.store.resetCreditBankRuns().isEmpty)
    }

    @MainActor
    @Test("reset credit schema has no raw identity or referral fields")
    func schemaContainsOnlySafeColumns() throws {
        let context = try TestStoreContext()
        defer { context.cleanup() }

        var database: OpaquePointer?
        #expect(sqlite3_open_v2(context.databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        defer { sqlite3_close(database) }
        let forbidden = Set(["raw_id", "description", "referral"])
        for table in ["reset_credits", "reset_credit_bank_runs"] {
            let columns = tableColumns(database: database, table: table)
            #expect(columns.isDisjoint(with: forbidden))
        }
    }

    @MainActor
    @Test("one pre-expiry disappearance becomes likely redeemed only after reset confirmation")
    func likelyRedemptionRequiresExplicitConfirmation() throws {
        let context = try TestStoreContext()
        defer { context.cleanup() }
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let credit = ResetCredit(
            fingerprint: String(repeating: "b", count: 64),
            resetType: "codexRateLimits",
            status: .available,
            grantedAt: now.addingTimeInterval(-86_400),
            grantTimeSource: .provider,
            expiresAt: now.addingTimeInterval(86_400),
            title: nil
        )
        context.store.recordResetCreditBank(ResetCreditBankSummary(
            availableCount: 1,
            credits: [credit],
            detailState: .complete,
            fetchedAt: now
        ))
        let disappearanceAt = now.addingTimeInterval(60)
        context.store.recordResetCreditBank(ResetCreditBankSummary(
            availableCount: 0,
            credits: [],
            detailState: .complete,
            fetchedAt: disappearanceAt
        ))

        #expect(context.store.resetCreditHistory().first?.lifecycle == .disappearedUnknown)
        context.store.confirmLikelyResetCreditRedemption(at: disappearanceAt)
        #expect(context.store.resetCreditHistory().first?.lifecycle == .likelyRedeemed)
    }

    private func tableColumns(database: OpaquePointer?, table: String) -> Set<String> {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA table_info(\(table))", -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }
        var result = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW, let pointer = sqlite3_column_text(statement, 1) {
            result.insert(String(cString: pointer))
        }
        return result
    }
}

@MainActor
private struct TestStoreContext {
    let directoryURL: URL
    let databaseURL: URL
    let suiteName: String
    let defaults: UserDefaults
    let store: QuotaHistoryStore

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quota-capsule-reset-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        databaseURL = directoryURL.appendingPathComponent("history.sqlite")
        suiteName = "quota-capsule-reset-tests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        let configuration = AppConfiguration(
            channel: .beta,
            displayName: "Quota Capsule Test",
            bundleIdentifier: "com.bono.quota-capsule.test",
            githubIssuesURL: nil,
            analyticsEndpointURL: nil,
            applicationSupportDirectoryName: "Quota Capsule Test",
            userDefaultsKeyPrefix: suiteName
        )
        store = QuotaHistoryStore(
            configuration: configuration,
            userDefaults: defaults,
            databaseURLOverride: databaseURL
        )
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
