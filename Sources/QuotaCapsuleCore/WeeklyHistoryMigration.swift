import Foundation

public struct StoredQuotaWindowRow: Equatable, Sendable {
    public let provider: String
    public let sourceStatus: SourceStatus
    public let fetchedAt: Date
    public let windowType: String
    public let windowMinutes: Int
    public let usedPercent: Double
    public let remainingPercent: Double
    public let resetsAt: Date
    public let legacyDerivedRate: Double?
    public let legacyProjectedRemaining: Double?
    public let legacyResetDetected: Bool

    public init(
        provider: String,
        sourceStatus: SourceStatus,
        fetchedAt: Date,
        windowType: String,
        windowMinutes: Int,
        usedPercent: Double,
        remainingPercent: Double,
        resetsAt: Date,
        legacyDerivedRate: Double?,
        legacyProjectedRemaining: Double?,
        legacyResetDetected: Bool
    ) {
        self.provider = provider
        self.sourceStatus = sourceStatus
        self.fetchedAt = fetchedAt
        self.windowType = windowType
        self.windowMinutes = windowMinutes
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
        self.legacyDerivedRate = legacyDerivedRate
        self.legacyProjectedRemaining = legacyProjectedRemaining
        self.legacyResetDetected = legacyResetDetected
    }
}

public enum WeeklyHistoryMigration {
    public static let schemaVersion = 3

    public static let cleanupStatements = [
        "DELETE FROM quota_windows WHERE window_type = '5h'",
        """
        UPDATE quota_windows
        SET time_elapsed_percent = NULL,
            burn_rate_percent_per_min = NULL,
            burn_rate_vs_even_pace = NULL,
            projected_remaining_at_reset = NULL,
            estimated_empty_at = NULL,
            used_delta_percent = NULL,
            delta_minutes = NULL,
            delta_percent_per_min = NULL,
            reset_detected = 0
        WHERE window_type = 'weekly'
        """,
        "DELETE FROM captures WHERE NOT EXISTS (SELECT 1 FROM quota_windows WHERE quota_windows.capture_id = captures.id)",
        "PRAGMA user_version = 3"
    ]

    public static func reading(from row: StoredQuotaWindowRow) -> WeeklyQuotaReading? {
        guard row.windowType == "weekly",
              row.sourceStatus == .ok,
              abs(row.windowMinutes - 10_080) <= 60,
              row.usedPercent.isFinite,
              row.remainingPercent.isFinite,
              (0...100).contains(row.usedPercent),
              (0...100).contains(row.remainingPercent),
              abs(row.usedPercent + row.remainingPercent - 100) <= 1.5,
              row.resetsAt > row.fetchedAt,
              row.resetsAt.timeIntervalSince(row.fetchedAt) <= 8 * 24 * 60 * 60 else {
            return nil
        }

        return WeeklyQuotaReading(
            provider: row.provider,
            sourceStatus: row.sourceStatus,
            fetchedAt: row.fetchedAt,
            windowMinutes: row.windowMinutes,
            usedPercent: row.usedPercent,
            remainingPercent: row.remainingPercent,
            resetsAt: row.resetsAt,
            errorMessage: nil
        )
    }
}
