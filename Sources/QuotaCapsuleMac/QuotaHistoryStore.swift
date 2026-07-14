import Foundation
import SQLite3
import QuotaCapsuleCore

enum AnalyticsConsent: String {
    case undecided
    case granted
    case denied
}

struct ProductAnalyticsEvent {
    let name: String
    let time: Date
    let surface: String?
    let status: CapsuleLevel?
    let sourceStatus: SourceStatus?
    let errorType: String?
    let durationSeconds: Double?
    let count: Int?
    let widthBucket: String?
    let language: QuotaLocale
    let feedbackTarget: String?
    let properties: [String: String]

    init(
        name: String,
        time: Date = Date(),
        surface: String? = nil,
        status: CapsuleLevel? = nil,
        sourceStatus: SourceStatus? = nil,
        errorType: String? = nil,
        durationSeconds: Double? = nil,
        count: Int? = nil,
        widthBucket: String? = nil,
        language: QuotaLocale,
        feedbackTarget: String? = nil,
        properties: [String: String] = [:]
    ) {
        self.name = name
        self.time = time
        self.surface = surface
        self.status = status
        self.sourceStatus = sourceStatus
        self.errorType = errorType
        self.durationSeconds = durationSeconds
        self.count = count
        self.widthBucket = widthBucket
        self.language = language
        self.feedbackTarget = feedbackTarget
        self.properties = properties
    }
}

struct PendingAnalyticsUpload {
    let id: Int64
    let payload: [String: Any]

    var isProductImprovement: Bool {
        guard let properties = payload["properties"] as? [String: Any] else { return false }
        return properties["collection_tier"] as? String == "product_improvement"
    }
}

@MainActor
final class QuotaHistoryStore {
    static let historySchemaVersion = WeeklyHistoryMigration.schemaVersion
    static let analyticsSchemaVersion = 1
    static let consentVersion = "2026-07-01-v1"

    private let databaseURL: URL
    private nonisolated(unsafe) var database: OpaquePointer?
    private let installIDHash: String
    private let configuration: AppConfiguration

    init(
        configuration: AppConfiguration,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        databaseURLOverride: URL? = nil
    ) {
        self.configuration = configuration
        let supportURL = QuotaHistoryStore.applicationSupportURL(
            fileManager: fileManager,
            directoryName: configuration.applicationSupportDirectoryName
        )
        try? fileManager.createDirectory(
            at: supportURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: supportURL.path)
        if let databaseURLOverride {
            databaseURL = databaseURLOverride
            try? fileManager.createDirectory(
                at: databaseURLOverride.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } else {
            databaseURL = supportURL.appendingPathComponent("QuotaCapsule.sqlite")
        }

        let installKey = configuration.userDefaultsKey("analytics.installID")
        let installID: String
        if let existing = userDefaults.string(forKey: installKey), !existing.isEmpty {
            installID = existing
        } else {
            installID = UUID().uuidString
            userDefaults.set(installID, forKey: installKey)
        }
        installIDHash = stableHash(installID)

        open()
        if !migrate() {
            sqlite3_close(database)
            database = nil
        }
        repairLegacyStaleSuccessCaptures()
        for suffix in ["", "-wal", "-shm"] {
            let path = databaseURL.path + suffix
            if fileManager.fileExists(atPath: path) {
                try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            }
        }
    }

    deinit {
        sqlite3_close(database)
    }

    var databasePath: String {
        databaseURL.path
    }

    var databaseSizeBytes: Int64 {
        (try? FileManager.default.attributesOfItem(atPath: databaseURL.path)[.size] as? Int64) ?? 0
    }

    func recordWeeklySnapshot(_ snapshot: AgentQuotaSnapshot) {
        guard snapshot.sourceStatus == .ok, let weeklyWindow = snapshot.weeklyWindow else { return }

        execute("BEGIN IMMEDIATE TRANSACTION")
        defer { execute("COMMIT") }

        let captureID = insertCapture(snapshot)
        guard captureID > 0 else { return }
        insertRawWeeklyWindow(captureID: captureID, snapshot: snapshot, window: weeklyWindow)
    }

    func recordResetCreditBank(_ bank: ResetCreditBankSummary) {
        guard database != nil else { return }
        execute("BEGIN IMMEDIATE TRANSACTION")
        defer { execute("COMMIT") }

        for credit in bank.credits ?? [] {
            upsertResetCredit(credit, observedAt: bank.fetchedAt)
        }
        coalesceResetCreditBankRun(bank)
        if bank.detailState == .complete, let credits = bank.credits {
            classifyMissingResetCredits(currentFingerprints: Set(credits.map(\.fingerprint)), observedAt: bank.fetchedAt)
        }
    }

    func resetCreditHistory() -> [ResetCreditHistoryRecord] {
        let sql = """
        SELECT fingerprint, reset_type, safe_title, granted_at, grant_time_source,
               expires_at, first_seen_at, last_seen_at, latest_status, lifecycle, sample_count
        FROM reset_credits
        ORDER BY first_seen_at ASC, fingerprint ASC
        """
        guard let statement = prepare(sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        var records: [ResetCreditHistoryRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            records.append(ResetCreditHistoryRecord(
                fingerprint: sqliteText(statement, column: 0),
                resetType: sqliteText(statement, column: 1),
                safeTitle: columnText(statement, 2),
                grantedAt: sqliteOptionalDouble(statement, column: 3).map(Date.init(timeIntervalSince1970:)),
                grantTimeSource: ResetCreditGrantTimeSource(rawValue: sqliteText(statement, column: 4)) ?? .unknown,
                expiresAt: sqliteOptionalDouble(statement, column: 5).map(Date.init(timeIntervalSince1970:)),
                firstSeenAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
                lastSeenAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7)),
                latestStatus: ResetCreditStatus(rawValue: sqliteText(statement, column: 8)) ?? .unknown,
                lifecycle: ResetCreditLifecycle(rawValue: sqliteText(statement, column: 9)) ?? .disappearedUnknown,
                sampleCount: Int(sqlite3_column_int(statement, 10))
            ))
        }
        return records
    }

    func resetCreditBankRuns() -> [ResetCreditBankRun] {
        let sql = """
        SELECT signature, first_observed_at, last_observed_at, sample_count,
               available_count, detail_count, detail_state
        FROM reset_credit_bank_runs
        ORDER BY id ASC
        """
        guard let statement = prepare(sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        var runs: [ResetCreditBankRun] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let detailCount = sqlite3_column_type(statement, 5) == SQLITE_NULL
                ? nil
                : Int(sqlite3_column_int(statement, 5))
            runs.append(ResetCreditBankRun(
                signature: sqliteText(statement, column: 0),
                firstObservedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
                lastObservedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                sampleCount: Int(sqlite3_column_int(statement, 3)),
                availableCount: Int(sqlite3_column_int(statement, 4)),
                detailCount: detailCount,
                detailState: ResetCreditDetailState(rawValue: sqliteText(statement, column: 6)) ?? .countOnly
            ))
        }
        return runs
    }

    func confirmLikelyResetCreditRedemption(at observedAt: Date) {
        let sql = """
        SELECT id, first_observed_at, last_observed_at, available_count, detail_state
        FROM reset_credit_bank_runs
        ORDER BY id DESC
        LIMIT 2
        """
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }
        var rows: [(first: Double, last: Double, count: Int, state: String)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append((
                first: sqlite3_column_double(statement, 1),
                last: sqlite3_column_double(statement, 2),
                count: Int(sqlite3_column_int(statement, 3)),
                state: sqliteText(statement, column: 4)
            ))
        }
        guard rows.count == 2 else { return }
        let current = rows[0]
        let previous = rows[1]
        guard current.state == ResetCreditDetailState.complete.rawValue,
              previous.state == ResetCreditDetailState.complete.rawValue,
              current.count == previous.count - 1,
              abs(current.last - observedAt.timeIntervalSince1970) <= 300 else {
            return
        }

        let candidates = disappearedResetCreditFingerprints(
            lastSeenFrom: previous.first,
            through: previous.last,
            observedAt: observedAt
        )
        guard candidates.count == 1, let fingerprint = candidates.first else { return }
        updateResetCreditLifecycle(.likelyRedeemed, fingerprint: fingerprint)
    }

    func recentWeeklyReadings(
        now: Date = Date(),
        limit: Int = WeeklyHistorySelection.defaultLimit
    ) -> [WeeklyQuotaReading] {
        let sql = """
        SELECT c.provider, c.source_status, c.fetched_at,
               w.window_type, w.window_minutes, w.used_percent,
               w.remaining_percent, w.resets_at,
               w.burn_rate_percent_per_min,
               w.projected_remaining_at_reset,
               w.reset_detected
        FROM quota_windows w
        JOIN captures c ON c.id = w.capture_id
        WHERE w.window_type = 'weekly' AND c.fetched_at >= ?
        ORDER BY c.fetched_at ASC, w.id ASC
        """
        guard let statement = prepare(sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        bindDouble(statement, 1, now.addingTimeInterval(-WeeklyHistorySelection.horizon).timeIntervalSince1970)

        var readings: [WeeklyQuotaReading] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let statusText = sqliteText(statement, column: 1)
            let status: SourceStatus
            switch statusText {
            case "success": status = .ok
            case "stale": status = .stale
            default: status = .error
            }
            let row = StoredQuotaWindowRow(
                provider: sqliteText(statement, column: 0),
                sourceStatus: status,
                fetchedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                windowType: sqliteText(statement, column: 3),
                windowMinutes: Int(sqlite3_column_int(statement, 4)),
                usedPercent: sqlite3_column_double(statement, 5),
                remainingPercent: sqlite3_column_double(statement, 6),
                resetsAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7)),
                legacyDerivedRate: sqliteOptionalDouble(statement, column: 8),
                legacyProjectedRemaining: sqliteOptionalDouble(statement, column: 9),
                legacyResetDetected: sqlite3_column_int(statement, 10) != 0
            )
            if let reading = WeeklyHistoryMigration.reading(from: row) {
                readings.append(reading)
            }
        }
        return WeeklyHistorySelection.compact(readings, now: now, limit: limit)
    }

    @discardableResult
    func recordEvent(
        _ event: ProductAnalyticsEvent,
        consent: AnalyticsConsent,
        uploadAllowed: Bool? = nil
    ) -> PendingAnalyticsUpload? {
        guard let payload = makePayload(event: event, consent: consent),
              let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let payloadJSON = String(data: payloadData, encoding: .utf8) else {
            return nil
        }

        let endpointConfigured = ProductAnalyticsUploader.endpointURL(configuration: configuration) != nil
        let mayUpload = uploadAllowed ?? (consent == .granted)
        let uploadStatus = mayUpload && endpointConfigured ? "pending" : "disabled"
        let queuedForUpload = uploadStatus == "pending" ? 1 : 0

        let sql = """
        INSERT INTO product_events (
          event_name, event_time, install_id_hash, app_version, schema_version,
          locale, macos_major_version, arch, analytics_consent_version,
          surface, status, source_status, error_type, duration_seconds, count,
          width_bucket, language, feedback_target, properties_json,
          payload_json, queued_for_upload, upload_status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        guard let statement = prepare(sql) else { return nil }
        defer { sqlite3_finalize(statement) }

        bindText(statement, 1, event.name)
        bindDouble(statement, 2, event.time.timeIntervalSince1970)
        bindText(statement, 3, installIDHash)
        bindText(statement, 4, appVersion())
        bindInt(statement, 5, Self.analyticsSchemaVersion)
        bindText(statement, 6, event.language.analyticsCode)
        bindInt(statement, 7, ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
        bindText(statement, 8, currentArchitecture())
        bindText(statement, 9, Self.consentVersion)
        bindOptionalText(statement, 10, event.surface)
        bindOptionalText(statement, 11, event.status?.analyticsCode)
        bindOptionalText(statement, 12, event.sourceStatus?.analyticsCode)
        bindOptionalText(statement, 13, event.errorType)
        bindOptionalDouble(statement, 14, event.durationSeconds)
        bindOptionalInt(statement, 15, event.count)
        bindOptionalText(statement, 16, event.widthBucket)
        bindText(statement, 17, event.language.analyticsCode)
        bindOptionalText(statement, 18, event.feedbackTarget)
        bindText(statement, 19, jsonString(event.properties))
        bindText(statement, 20, payloadJSON)
        bindInt(statement, 21, queuedForUpload)
        bindText(statement, 22, uploadStatus)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            return nil
        }

        let rowID = sqlite3_last_insert_rowid(database)
        guard queuedForUpload == 1 else { return nil }
        return PendingAnalyticsUpload(id: rowID, payload: payload)
    }

    func pendingUploads(limit: Int = 20) -> [PendingAnalyticsUpload] {
        let sql = """
        SELECT id, payload_json FROM product_events
        WHERE upload_status = 'pending'
        ORDER BY id ASC
        LIMIT ?
        """
        guard let statement = prepare(sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        bindInt(statement, 1, limit)

        var uploads: [PendingAnalyticsUpload] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)
            guard let payloadText = columnText(statement, 1),
                  let data = payloadText.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            uploads.append(PendingAnalyticsUpload(id: id, payload: payload))
        }
        return uploads
    }

    func markUploadSent(id: Int64) {
        execute("UPDATE product_events SET upload_status = 'sent', queued_for_upload = 0 WHERE id = \(id)")
    }

    func markUploadFailed(id: Int64) {
        execute("UPDATE product_events SET upload_status = 'failed' WHERE id = \(id)")
    }

    func disableUpload(id: Int64) {
        execute("UPDATE product_events SET upload_status = 'disabled', queued_for_upload = 0 WHERE id = \(id)")
    }

    func disablePendingProductImprovementUploads() {
        execute("""
        UPDATE product_events
        SET upload_status = 'disabled', queued_for_upload = 0
        WHERE upload_status = 'pending'
          AND properties_json LIKE '%\"collection_tier\":\"product_improvement\"%'
        """)
    }

    func clearAll() {
        execute("DELETE FROM reset_credit_bank_runs")
        execute("DELETE FROM reset_credits")
        execute("DELETE FROM quota_windows")
        execute("DELETE FROM captures")
        execute("DELETE FROM product_events")
        execute("VACUUM")
    }

    private static func applicationSupportURL(fileManager: FileManager, directoryName: String) -> URL {
        if let url = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            return url.appendingPathComponent(directoryName, isDirectory: true)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(directoryName, isDirectory: true)
    }

    private func open() {
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            database = nil
            return
        }
        guard execute("PRAGMA journal_mode = WAL"),
              execute("PRAGMA foreign_keys = ON") else {
            sqlite3_close(database)
            database = nil
            return
        }
    }

    private func migrate() -> Bool {
        guard execute("""
        CREATE TABLE IF NOT EXISTS captures (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          captured_at REAL NOT NULL,
          provider TEXT NOT NULL,
          source TEXT NOT NULL,
          source_status TEXT NOT NULL,
          fetched_at REAL NOT NULL,
          data_age_seconds REAL NOT NULL,
          app_version TEXT NOT NULL,
          schema_version INTEGER NOT NULL,
          error_type TEXT,
          error_message_hash TEXT
        )
        """) else { return false }

        guard execute("""
        CREATE TABLE IF NOT EXISTS quota_windows (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          capture_id INTEGER NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
          window_type TEXT NOT NULL,
          window_minutes INTEGER NOT NULL,
          used_percent REAL NOT NULL,
          remaining_percent REAL NOT NULL,
          resets_at REAL NOT NULL,
          window_start REAL NOT NULL,
          time_elapsed_percent INTEGER,
          minutes_until_reset REAL,
          burn_rate_percent_per_min REAL,
          burn_rate_vs_even_pace REAL,
          projected_remaining_at_reset INTEGER,
          estimated_empty_at REAL,
          state TEXT NOT NULL,
          used_delta_percent REAL,
          delta_minutes REAL,
          delta_percent_per_min REAL,
          reset_detected INTEGER NOT NULL DEFAULT 0
        )
        """) else { return false }

        guard execute("""
        CREATE TABLE IF NOT EXISTS product_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          event_name TEXT NOT NULL,
          event_time REAL NOT NULL,
          install_id_hash TEXT NOT NULL,
          app_version TEXT NOT NULL,
          schema_version INTEGER NOT NULL,
          locale TEXT NOT NULL,
          macos_major_version INTEGER NOT NULL,
          arch TEXT NOT NULL,
          analytics_consent_version TEXT NOT NULL,
          surface TEXT,
          status TEXT,
          source_status TEXT,
          error_type TEXT,
          duration_seconds REAL,
          count INTEGER,
          width_bucket TEXT,
          language TEXT NOT NULL,
          feedback_target TEXT,
          properties_json TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          queued_for_upload INTEGER NOT NULL,
          upload_status TEXT NOT NULL
        )
        """) else { return false }

        guard execute("""
        CREATE TABLE IF NOT EXISTS reset_credits (
          fingerprint TEXT PRIMARY KEY,
          reset_type TEXT NOT NULL,
          safe_title TEXT,
          granted_at REAL,
          grant_time_source TEXT NOT NULL,
          expires_at REAL,
          first_seen_at REAL NOT NULL,
          last_seen_at REAL NOT NULL,
          latest_status TEXT NOT NULL,
          lifecycle TEXT NOT NULL,
          sample_count INTEGER NOT NULL
        )
        """) else { return false }

        guard execute("""
        CREATE TABLE IF NOT EXISTS reset_credit_bank_runs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          signature TEXT NOT NULL,
          first_observed_at REAL NOT NULL,
          last_observed_at REAL NOT NULL,
          sample_count INTEGER NOT NULL,
          available_count INTEGER NOT NULL,
          detail_count INTEGER,
          detail_state TEXT NOT NULL
        )
        """) else { return false }

        guard execute("CREATE INDEX IF NOT EXISTS idx_captures_captured_at ON captures(captured_at)"),
              execute("CREATE INDEX IF NOT EXISTS idx_windows_type_time ON quota_windows(window_type, resets_at)"),
              execute("CREATE INDEX IF NOT EXISTS idx_events_name_time ON product_events(event_name, event_time)"),
              execute("CREATE INDEX IF NOT EXISTS idx_events_upload ON product_events(upload_status, id)"),
              execute("CREATE INDEX IF NOT EXISTS idx_reset_credits_granted ON reset_credits(granted_at)"),
              execute("CREATE INDEX IF NOT EXISTS idx_reset_credits_expires ON reset_credits(expires_at)"),
              execute("CREATE INDEX IF NOT EXISTS idx_reset_bank_runs_last ON reset_credit_bank_runs(last_observed_at)") else {
            return false
        }

        guard execute("BEGIN IMMEDIATE TRANSACTION") else { return false }
        for statement in WeeklyHistoryMigration.cleanupStatements {
            guard execute(statement) else {
                execute("ROLLBACK")
                return false
            }
        }
        guard execute(WeeklyHistoryMigration.versionStatement) else {
            execute("ROLLBACK")
            return false
        }
        guard execute("COMMIT") else {
            execute("ROLLBACK")
            return false
        }
        return true
    }

    private func repairLegacyStaleSuccessCaptures() {
        // Builds before schema v2 recorded the cached display snapshot after a
        // failed refresh, producing old rows labelled as fresh success. Genuine
        // successful reads are captured within seconds of fetched_at.
        execute("""
        DELETE FROM quota_windows
        WHERE capture_id IN (
          SELECT id FROM captures
          WHERE source_status = 'success' AND data_age_seconds > 120
        )
        """)
        execute("""
        DELETE FROM captures
        WHERE source_status = 'success' AND data_age_seconds > 120
        """)
    }

    private func upsertResetCredit(_ credit: ResetCredit, observedAt: Date) {
        let lifecycle: ResetCreditLifecycle = credit.status == .redeemed ? .likelyRedeemed : .available
        let sql = """
        INSERT INTO reset_credits (
          fingerprint, reset_type, safe_title, granted_at, grant_time_source, expires_at,
          first_seen_at, last_seen_at, latest_status, lifecycle, sample_count
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        ON CONFLICT(fingerprint) DO UPDATE SET
          reset_type = excluded.reset_type,
          safe_title = COALESCE(reset_credits.safe_title, excluded.safe_title),
          granted_at = CASE
            WHEN reset_credits.grant_time_source = 'provider' THEN reset_credits.granted_at
            WHEN excluded.grant_time_source = 'provider' THEN excluded.granted_at
            ELSE COALESCE(reset_credits.granted_at, excluded.granted_at)
          END,
          grant_time_source = CASE
            WHEN reset_credits.grant_time_source = 'provider' THEN reset_credits.grant_time_source
            WHEN excluded.grant_time_source = 'provider' THEN excluded.grant_time_source
            WHEN reset_credits.granted_at IS NOT NULL THEN reset_credits.grant_time_source
            ELSE excluded.grant_time_source
          END,
          expires_at = COALESCE(reset_credits.expires_at, excluded.expires_at),
          last_seen_at = excluded.last_seen_at,
          latest_status = excluded.latest_status,
          lifecycle = excluded.lifecycle,
          sample_count = reset_credits.sample_count + 1
        """
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, credit.fingerprint)
        bindText(statement, 2, credit.resetType)
        bindOptionalText(statement, 3, credit.title)
        bindOptionalDouble(statement, 4, credit.grantedAt?.timeIntervalSince1970)
        bindText(statement, 5, credit.grantTimeSource.rawValue)
        bindOptionalDouble(statement, 6, credit.expiresAt?.timeIntervalSince1970)
        bindDouble(statement, 7, observedAt.timeIntervalSince1970)
        bindDouble(statement, 8, observedAt.timeIntervalSince1970)
        bindText(statement, 9, credit.status.rawValue)
        bindText(statement, 10, lifecycle.rawValue)
        _ = sqlite3_step(statement)
    }

    private func coalesceResetCreditBankRun(_ bank: ResetCreditBankSummary) {
        let pairs = (bank.credits ?? [])
            .map { "\($0.fingerprint):\($0.status.rawValue)" }
            .sorted()
            .joined(separator: "|")
        let signature = stableHash("\(bank.availableCount)|\(bank.detailState.rawValue)|\(pairs)")
        let latestSQL = "SELECT id, signature FROM reset_credit_bank_runs ORDER BY id DESC LIMIT 1"
        var latestID: Int64?
        var latestSignature: String?
        if let statement = prepare(latestSQL) {
            if sqlite3_step(statement) == SQLITE_ROW {
                latestID = sqlite3_column_int64(statement, 0)
                latestSignature = sqliteText(statement, column: 1)
            }
            sqlite3_finalize(statement)
        }

        if let latestID, latestSignature == signature {
            let updateSQL = """
            UPDATE reset_credit_bank_runs
            SET last_observed_at = ?, sample_count = sample_count + 1
            WHERE id = ?
            """
            guard let statement = prepare(updateSQL) else { return }
            defer { sqlite3_finalize(statement) }
            bindDouble(statement, 1, bank.fetchedAt.timeIntervalSince1970)
            bindInt64(statement, 2, latestID)
            _ = sqlite3_step(statement)
            return
        }

        let insertSQL = """
        INSERT INTO reset_credit_bank_runs (
          signature, first_observed_at, last_observed_at, sample_count,
          available_count, detail_count, detail_state
        ) VALUES (?, ?, ?, 1, ?, ?, ?)
        """
        guard let statement = prepare(insertSQL) else { return }
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, signature)
        bindDouble(statement, 2, bank.fetchedAt.timeIntervalSince1970)
        bindDouble(statement, 3, bank.fetchedAt.timeIntervalSince1970)
        bindInt(statement, 4, bank.availableCount)
        bindOptionalInt(statement, 5, bank.credits?.count)
        bindText(statement, 6, bank.detailState.rawValue)
        _ = sqlite3_step(statement)
    }

    private func classifyMissingResetCredits(currentFingerprints: Set<String>, observedAt: Date) {
        let sql = """
        SELECT fingerprint, expires_at
        FROM reset_credits
        WHERE lifecycle = 'available'
        """
        guard let statement = prepare(sql) else { return }
        var missing: [(fingerprint: String, expiresAt: Date?)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let fingerprint = sqliteText(statement, column: 0)
            if !currentFingerprints.contains(fingerprint) {
                missing.append((
                    fingerprint,
                    sqliteOptionalDouble(statement, column: 1).map(Date.init(timeIntervalSince1970:))
                ))
            }
        }
        sqlite3_finalize(statement)

        for item in missing {
            let lifecycle = ResetCreditLifecycleClassifier.classifyDisappearance(
                expiresAt: item.expiresAt,
                observedAt: observedAt,
                compatibleResetConfirmed: false
            )
            updateResetCreditLifecycle(lifecycle, fingerprint: item.fingerprint)
        }
    }

    private func disappearedResetCreditFingerprints(
        lastSeenFrom: Double,
        through lastSeenThrough: Double,
        observedAt: Date
    ) -> [String] {
        let sql = """
        SELECT fingerprint
        FROM reset_credits
        WHERE lifecycle = 'disappearedUnknown'
          AND latest_status = 'available'
          AND last_seen_at >= ? AND last_seen_at <= ?
          AND (expires_at IS NULL OR expires_at > ?)
        ORDER BY fingerprint ASC
        """
        guard let statement = prepare(sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        bindDouble(statement, 1, lastSeenFrom)
        bindDouble(statement, 2, lastSeenThrough)
        bindDouble(statement, 3, observedAt.timeIntervalSince1970)
        var fingerprints: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            fingerprints.append(sqliteText(statement, column: 0))
        }
        return fingerprints
    }

    private func updateResetCreditLifecycle(_ lifecycle: ResetCreditLifecycle, fingerprint: String) {
        let sql = "UPDATE reset_credits SET lifecycle = ? WHERE fingerprint = ?"
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, lifecycle.rawValue)
        bindText(statement, 2, fingerprint)
        _ = sqlite3_step(statement)
    }

    private func insertCapture(_ snapshot: AgentQuotaSnapshot) -> Int64 {
        let sql = """
        INSERT INTO captures (
          captured_at, provider, source, source_status, fetched_at, data_age_seconds,
          app_version, schema_version, error_type, error_message_hash
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        guard let statement = prepare(sql) else { return 0 }
        defer { sqlite3_finalize(statement) }

        let capturedAt = Date()
        let errorType = snapshot.errorMessage.map(classifyError)
        let errorHash = snapshot.errorMessage.map(stableHash)

        bindDouble(statement, 1, capturedAt.timeIntervalSince1970)
        bindText(statement, 2, snapshot.provider)
        bindText(statement, 3, "codex_app_server")
        bindText(statement, 4, snapshot.sourceStatus.analyticsCode)
        bindDouble(statement, 5, snapshot.fetchedAt.timeIntervalSince1970)
        bindDouble(statement, 6, capturedAt.timeIntervalSince(snapshot.fetchedAt))
        bindText(statement, 7, appVersion())
        bindInt(statement, 8, Self.historySchemaVersion)
        bindOptionalText(statement, 9, errorType)
        bindOptionalText(statement, 10, errorHash)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            return 0
        }
        return sqlite3_last_insert_rowid(database)
    }

    private func insertRawWeeklyWindow(
        captureID: Int64,
        snapshot: AgentQuotaSnapshot,
        window: QuotaWindow
    ) {
        let windowStart = window.resetsAt.addingTimeInterval(TimeInterval(-window.windowMinutes * 60))
        let minutesUntilReset = window.resetsAt.timeIntervalSince(snapshot.fetchedAt) / 60
        let sql = """
        INSERT INTO quota_windows (
          capture_id, window_type, window_minutes, used_percent, remaining_percent,
          resets_at, window_start, time_elapsed_percent, minutes_until_reset,
          burn_rate_percent_per_min, burn_rate_vs_even_pace,
          projected_remaining_at_reset, estimated_empty_at, state,
          used_delta_percent, delta_minutes, delta_percent_per_min, reset_detected
        ) VALUES (?, 'weekly', ?, ?, ?, ?, ?, NULL, ?, NULL, NULL, NULL, NULL, 'raw', NULL, NULL, NULL, 0)
        """
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }
        bindInt64(statement, 1, captureID)
        bindInt(statement, 2, window.windowMinutes)
        bindDouble(statement, 3, window.usedPercent)
        bindDouble(statement, 4, window.remainingPercent)
        bindDouble(statement, 5, window.resetsAt.timeIntervalSince1970)
        bindDouble(statement, 6, windowStart.timeIntervalSince1970)
        bindDouble(statement, 7, minutesUntilReset)
        _ = sqlite3_step(statement)
    }

    private func makePayload(event: ProductAnalyticsEvent, consent: AnalyticsConsent) -> [String: Any]? {
        var payload: [String: Any] = [
            "event_id": UUID().uuidString,
            "event_name": event.name,
            "event_time": event.time.timeIntervalSince1970,
            "install_id_hash": installIDHash,
            "app_version": appVersion(),
            "release_channel": configuration.channel.rawValue,
            "schema_version": Self.analyticsSchemaVersion,
            "locale": event.language.analyticsCode,
            "macos_major_version": ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            "arch": currentArchitecture(),
            "analytics_consent_version": Self.consentVersion,
            "consent": consent.rawValue,
            "language": event.language.analyticsCode,
            "properties": event.properties
        ]

        if let surface = event.surface { payload["surface"] = surface }
        if let status = event.status?.analyticsCode { payload["status"] = status }
        if let sourceStatus = event.sourceStatus?.analyticsCode { payload["source_status"] = sourceStatus }
        if let errorType = event.errorType { payload["error_type"] = errorType }
        if let durationSeconds = event.durationSeconds { payload["duration_seconds"] = durationSeconds }
        if let count = event.count { payload["count"] = count }
        if let widthBucket = event.widthBucket { payload["width_bucket"] = widthBucket }
        if let feedbackTarget = event.feedbackTarget { payload["feedback_target"] = feedbackTarget }
        return payload
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        guard let database else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        return statement
    }

    private func sqliteText(_ statement: OpaquePointer, column: Int32) -> String {
        guard let value = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: value)
    }

    private func sqliteOptionalDouble(_ statement: OpaquePointer, column: Int32) -> Double? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, column)
    }

    @discardableResult
    private func execute(_ sql: String) -> Bool {
        guard let database else { return false }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        if let errorMessage {
            sqlite3_free(errorMessage)
        }
        return result == SQLITE_OK
    }
}

struct ProductAnalyticsUploader {
    static func endpointURL(configuration: AppConfiguration) -> URL? {
        configuration.analyticsEndpointURL
    }

    static func upload(payload: [String: Any], configuration: AppConfiguration) async -> Bool {
        guard let endpoint = endpointURL(configuration: configuration),
              JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return false
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func bindText(_ statement: OpaquePointer?, _ index: Int32, _ value: String) {
    sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
}

private func bindOptionalText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
    if let value {
        bindText(statement, index, value)
    } else {
        sqlite3_bind_null(statement, index)
    }
}

private func bindInt(_ statement: OpaquePointer?, _ index: Int32, _ value: Int) {
    sqlite3_bind_int(statement, index, Int32(value))
}

private func bindOptionalInt(_ statement: OpaquePointer?, _ index: Int32, _ value: Int?) {
    if let value {
        bindInt(statement, index, value)
    } else {
        sqlite3_bind_null(statement, index)
    }
}

private func bindInt64(_ statement: OpaquePointer?, _ index: Int32, _ value: Int64) {
    sqlite3_bind_int64(statement, index, value)
}

private func bindDouble(_ statement: OpaquePointer?, _ index: Int32, _ value: Double) {
    sqlite3_bind_double(statement, index, value)
}

private func bindOptionalDouble(_ statement: OpaquePointer?, _ index: Int32, _ value: Double?) {
    if let value {
        bindDouble(statement, index, value)
    } else {
        sqlite3_bind_null(statement, index)
    }
}

private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard let pointer = sqlite3_column_text(statement, index) else { return nil }
    return String(cString: pointer)
}

private func appVersion() -> String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0-dev"
}

private func currentArchitecture() -> String {
    #if arch(arm64)
    return "arm64"
    #elseif arch(x86_64)
    return "x86_64"
    #else
    return "unknown"
    #endif
}

private func classifyError(_ message: String) -> String {
    let lowercased = message.lowercased()
    if lowercased.contains("not signed in") || lowercased.contains("未登录") || lowercased.contains("未登入") {
        return "auth_required"
    }
    if lowercased.contains("找不到 codex") || lowercased.contains("could not find") {
        return "missing_cli"
    }
    if lowercased.contains("timeout") || lowercased.contains("超时") || lowercased.contains("逾時") {
        return "timeout"
    }
    if lowercased.contains("ratelimits") {
        return "malformed_rate_limits"
    }
    return "source_error"
}

private func stableHash(_ value: String) -> String {
    let data = Data(value.utf8)
    var hash = UInt64(14_695_981_039_346_656_037)
    for byte in data {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
    }
    return String(format: "%016llx", hash)
}

private func jsonString(_ value: [String: String]) -> String {
    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
          let text = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return text
}

private extension CapsuleLevel {
    var analyticsCode: String {
        switch self {
        case .safe: "safe"
        case .watch: "watch"
        case .danger: "danger"
        case .unknown: "unknown"
        }
    }
}

private extension SourceStatus {
    var analyticsCode: String {
        switch self {
        case .ok: "success"
        case .stale: "stale"
        case .error: "failed"
        }
    }
}

extension QuotaLocale {
    var analyticsCode: String {
        switch self {
        case .zhHans: "zh-Hans"
        case .zhHant: "zh-Hant"
        case .en: "en"
        }
    }
}
