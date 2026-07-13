@testable import QuotaCapsuleCore
import Foundation
import Testing

@Suite("Weekly history migration")
struct WeeklyHistoryMigrationTests {
    private let fetchedAt = Date(timeIntervalSince1970: 2_000_000_000)

    private func row(
        type: String = "weekly",
        minutes: Int = 10_080,
        used: Double = 24,
        remaining: Double = 76,
        resetOffset: TimeInterval = 4 * 86_400,
        legacyRate: Double? = 99_999
    ) -> StoredQuotaWindowRow {
        StoredQuotaWindowRow(
            provider: "codex",
            sourceStatus: .ok,
            fetchedAt: fetchedAt,
            windowType: type,
            windowMinutes: minutes,
            usedPercent: used,
            remainingPercent: remaining,
            resetsAt: fetchedAt.addingTimeInterval(resetOffset),
            legacyDerivedRate: legacyRate,
            legacyProjectedRemaining: -9_999,
            legacyResetDetected: true
        )
    }

    @Test("schema v3 explicitly purges short windows and derived fields")
    func migrationContractIsWeeklyAndRawOnly() {
        #expect(WeeklyHistoryMigration.schemaVersion == 3)
        #expect(WeeklyHistoryMigration.cleanupStatements.contains { $0.contains("window_type = '5h'") })
        #expect(WeeklyHistoryMigration.cleanupStatements.contains { $0.contains("burn_rate_percent_per_min = NULL") })
        #expect(WeeklyHistoryMigration.cleanupStatements.contains { $0.contains("reset_detected = 0") })
        #expect(WeeklyHistoryMigration.cleanupStatements.allSatisfy { !$0.contains("user_version") })
        #expect(WeeklyHistoryMigration.versionStatement == "PRAGMA user_version = 3")
    }

    @Test("history selection keeps a full two-cycle horizon before applying its bound")
    func historySelectionPreservesLongHorizon() {
        let now = fetchedAt.addingTimeInterval(15 * 86_400)
        let readings = (0...(15 * 24 * 60)).map { minute in
            WeeklyQuotaReading(
                provider: "codex",
                sourceStatus: .ok,
                fetchedAt: fetchedAt.addingTimeInterval(TimeInterval(minute * 60)),
                windowMinutes: 10_080,
                usedPercent: 20,
                remainingPercent: 80,
                resetsAt: now.addingTimeInterval(86_400),
                errorMessage: nil
            )
        }

        let selected = WeeklyHistorySelection.compact(readings, now: now)

        #expect(selected.count <= WeeklyHistorySelection.defaultLimit)
        #expect(selected.first?.fetchedAt == fetchedAt)
        #expect(selected.last?.fetchedAt == now)
        #expect(selected.count >= 15 * 24 * 4)
    }

    @Test("a valid weekly row remains queryable without legacy derivatives")
    func validWeeklyRowSurvives() {
        let reading = WeeklyHistoryMigration.reading(from: row())

        #expect(reading?.provider == "codex")
        #expect(reading?.usedPercent == 24)
        #expect(reading?.remainingPercent == 76)
        #expect(reading?.windowMinutes == 10_080)
    }

    @Test("five-hour rows never become weekly history")
    func shortRowsAreRejected() {
        #expect(WeeklyHistoryMigration.reading(from: row(type: "5h", minutes: 300)) == nil)
    }

    @Test("structurally invalid weekly rows are quarantined")
    func invalidRowsAreRejected() {
        #expect(WeeklyHistoryMigration.reading(from: row(used: 130, remaining: -30)) == nil)
        #expect(WeeklyHistoryMigration.reading(from: row(used: 24, remaining: 60)) == nil)
        #expect(WeeklyHistoryMigration.reading(from: row(resetOffset: -60)) == nil)
        #expect(WeeklyHistoryMigration.reading(from: row(minutes: 1_440)) == nil)
    }
}
