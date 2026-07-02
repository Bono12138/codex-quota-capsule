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
}

@MainActor
final class QuotaHistoryStore {
    static let schemaVersion = 1
    static let consentVersion = "2026-07-01-v1"

    private let databaseURL: URL
    private nonisolated(unsafe) var database: OpaquePointer?
    private let installIDHash: String
    private let configuration: AppConfiguration

    init(
        configuration: AppConfiguration,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        let supportURL = QuotaHistoryStore.applicationSupportURL(
            fileManager: fileManager,
            directoryName: configuration.applicationSupportDirectoryName
        )
        try? fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
        databaseURL = supportURL.appendingPathComponent("QuotaCapsule.sqlite")

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
        migrate()
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

    func recordSnapshot(_ snapshot: AgentQuotaSnapshot, prediction: CapsulePrediction, locale: QuotaLocale) {
        guard let database else { return }

        execute("BEGIN IMMEDIATE TRANSACTION")
        defer { execute("COMMIT") }

        let captureID = insertCapture(snapshot)
        guard captureID > 0 else { return }

        if let shortWindow = snapshot.shortWindow {
            let windowPrediction = QuotaPredictor.predict(window: shortWindow, now: snapshot.fetchedAt, locale: locale)
            insertWindowRecord(captureID: captureID, snapshot: snapshot, window: shortWindow, windowType: "5h", prediction: windowPrediction)
        }

        if let weeklyWindow = snapshot.weeklyWindow {
            let windowPrediction = QuotaPredictor.predict(window: weeklyWindow, now: snapshot.fetchedAt, locale: locale)
            insertWindowRecord(captureID: captureID, snapshot: snapshot, window: weeklyWindow, windowType: "weekly", prediction: windowPrediction)
        }

        _ = database
    }

    @discardableResult
    func recordEvent(_ event: ProductAnalyticsEvent, consent: AnalyticsConsent) -> PendingAnalyticsUpload? {
        guard let payload = makePayload(event: event, consent: consent),
              let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let payloadJSON = String(data: payloadData, encoding: .utf8) else {
            return nil
        }

        let endpointConfigured = ProductAnalyticsUploader.endpointURL(configuration: configuration) != nil
        let uploadStatus = consent == .granted && endpointConfigured ? "pending" : "disabled"
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
        bindInt(statement, 5, Self.schemaVersion)
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

    func clearAll() {
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
        execute("PRAGMA journal_mode = WAL")
        execute("PRAGMA foreign_keys = ON")
    }

    private func migrate() {
        execute("""
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
        """)

        execute("""
        CREATE TABLE IF NOT EXISTS quota_windows (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          capture_id INTEGER NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
          window_type TEXT NOT NULL,
          window_minutes INTEGER NOT NULL,
          used_percent INTEGER NOT NULL,
          remaining_percent INTEGER NOT NULL,
          resets_at REAL NOT NULL,
          window_start REAL NOT NULL,
          time_elapsed_percent INTEGER,
          minutes_until_reset REAL,
          burn_rate_percent_per_min REAL,
          burn_rate_vs_even_pace REAL,
          projected_remaining_at_reset INTEGER,
          estimated_empty_at REAL,
          state TEXT NOT NULL,
          used_delta_percent INTEGER,
          delta_minutes REAL,
          delta_percent_per_min REAL,
          reset_detected INTEGER NOT NULL DEFAULT 0
        )
        """)

        execute("""
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
        """)

        execute("CREATE INDEX IF NOT EXISTS idx_captures_captured_at ON captures(captured_at)")
        execute("CREATE INDEX IF NOT EXISTS idx_windows_type_time ON quota_windows(window_type, resets_at)")
        execute("CREATE INDEX IF NOT EXISTS idx_events_name_time ON product_events(event_name, event_time)")
        execute("CREATE INDEX IF NOT EXISTS idx_events_upload ON product_events(upload_status, id)")
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
        bindInt(statement, 8, Self.schemaVersion)
        bindOptionalText(statement, 9, errorType)
        bindOptionalText(statement, 10, errorHash)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            return 0
        }
        return sqlite3_last_insert_rowid(database)
    }

    private func insertWindowRecord(
        captureID: Int64,
        snapshot: AgentQuotaSnapshot,
        window: QuotaWindow,
        windowType: String,
        prediction: CapsulePrediction
    ) {
        let previous = latestWindowSample(windowType: windowType)
        let capturedAt = snapshot.fetchedAt
        let windowStart = window.resetsAt.addingTimeInterval(TimeInterval(-window.windowMinutes * 60))
        let elapsedMinutes = max(0, capturedAt.timeIntervalSince(windowStart) / 60)
        let minutesUntilReset = window.resetsAt.timeIntervalSince(capturedAt) / 60
        let burnRate = elapsedMinutes > 0 ? Double(window.usedPercent) / elapsedMinutes : nil
        let burnRateVsEvenPace = prediction.elapsedPercent.flatMap { elapsedPercent -> Double? in
            guard elapsedPercent > 0 else { return nil }
            return Double(window.usedPercent) / Double(elapsedPercent)
        }
        let resetDetected = previous.map { abs($0.resetsAt.timeIntervalSince(window.resetsAt)) > 1 } ?? false
        let usedDelta = previous.map { window.usedPercent - $0.usedPercent }
        let deltaMinutes = previous.map { capturedAt.timeIntervalSince($0.capturedAt) / 60 }
        let deltaPercentPerMinute: Double?
        if let usedDelta, let deltaMinutes, deltaMinutes > 0 {
            deltaPercentPerMinute = Double(usedDelta) / deltaMinutes
        } else {
            deltaPercentPerMinute = nil
        }

        let sql = """
        INSERT INTO quota_windows (
          capture_id, window_type, window_minutes, used_percent, remaining_percent,
          resets_at, window_start, time_elapsed_percent, minutes_until_reset,
          burn_rate_percent_per_min, burn_rate_vs_even_pace,
          projected_remaining_at_reset, estimated_empty_at, state,
          used_delta_percent, delta_minutes, delta_percent_per_min, reset_detected
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }

        bindInt64(statement, 1, captureID)
        bindText(statement, 2, windowType)
        bindInt(statement, 3, window.windowMinutes)
        bindInt(statement, 4, window.usedPercent)
        bindInt(statement, 5, window.remainingPercent)
        bindDouble(statement, 6, window.resetsAt.timeIntervalSince1970)
        bindDouble(statement, 7, windowStart.timeIntervalSince1970)
        bindOptionalInt(statement, 8, prediction.elapsedPercent)
        bindDouble(statement, 9, minutesUntilReset)
        bindOptionalDouble(statement, 10, burnRate)
        bindOptionalDouble(statement, 11, burnRateVsEvenPace)
        bindOptionalInt(statement, 12, prediction.projectedRemainingAtReset)
        bindOptionalDouble(statement, 13, prediction.estimatedEmptyAt?.timeIntervalSince1970)
        bindText(statement, 14, prediction.level.analyticsCode)
        bindOptionalInt(statement, 15, usedDelta)
        bindOptionalDouble(statement, 16, deltaMinutes)
        bindOptionalDouble(statement, 17, deltaPercentPerMinute)
        bindInt(statement, 18, resetDetected ? 1 : 0)
        _ = sqlite3_step(statement)
    }

    private func latestWindowSample(windowType: String) -> (usedPercent: Int, capturedAt: Date, resetsAt: Date)? {
        let sql = """
        SELECT w.used_percent, c.fetched_at, w.resets_at
        FROM quota_windows w
        JOIN captures c ON c.id = w.capture_id
        WHERE w.window_type = ?
        ORDER BY w.id DESC
        LIMIT 1
        """
        guard let statement = prepare(sql) else { return nil }
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, windowType)

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return (
            Int(sqlite3_column_int(statement, 0)),
            Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
            Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
        )
    }

    private func makePayload(event: ProductAnalyticsEvent, consent: AnalyticsConsent) -> [String: Any]? {
        var payload: [String: Any] = [
            "event_id": UUID().uuidString,
            "event_name": event.name,
            "event_time": event.time.timeIntervalSince1970,
            "install_id_hash": installIDHash,
            "app_version": appVersion(),
            "release_channel": configuration.channel.rawValue,
            "schema_version": Self.schemaVersion,
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

    private func execute(_ sql: String) {
        guard let database else { return }
        sqlite3_exec(database, sql, nil, nil, nil)
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
