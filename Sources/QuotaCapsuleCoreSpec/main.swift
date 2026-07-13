import Foundation
import QuotaCapsuleCore
import SQLite3

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Spec failed: \(message)\n", stderr)
        exit(1)
    }
}

func weeklySnapshot(
    fetchedAt: Date,
    usedPercent: Double = 24,
    sourceStatus: SourceStatus = .ok,
    errorMessage: String? = nil
) -> AgentQuotaSnapshot {
    AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: sourceStatus,
        fetchedAt: fetchedAt,
        weeklyWindow: sourceStatus == .ok ? QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: usedPercent,
            remainingPercent: 100 - usedPercent,
            resetsAt: fetchedAt.addingTimeInterval(6 * 86_400)
        ) : nil,
        errorMessage: errorMessage
    )
}

func testParsesOnlyTheWeeklyWindow() throws {
    let fetchedAt = Date(timeIntervalSince1970: 1_788_270_000)
    let result = """
    {
      "rateLimits": {
        "primary": { "usedPercent": 41, "windowDurationMins": 10080, "resetsAt": 1788299735 },
        "secondary": { "usedPercent": 17, "windowDurationMins": 300, "resetsAt": 1788271414 }
      }
    }
    """.data(using: .utf8)!

    let snapshot = try CodexRateLimitParser.parse(resultData: result, fetchedAt: fetchedAt)
    expect(snapshot.sourceStatus == .ok, "weekly payload should parse")
    expect(snapshot.weeklyWindow?.windowMinutes == 10_080, "the selected window must be weekly")
    expect(snapshot.weeklyWindow?.usedPercent == 41, "weekly usage must retain its source value")
}

func testRejectsPayloadWithoutWeeklyWindow() {
    let snapshot = CodexRateLimitParser.parse(
        result: [
            "rateLimits": [
                "primary": ["usedPercent": 17, "windowDurationMins": 300, "resetsAt": 1_788_271_414]
            ]
        ],
        fetchedAt: Date(timeIntervalSince1970: 1_788_270_000)
    )
    expect(snapshot.sourceStatus == .error, "non-weekly data must not become a successful snapshot")
    expect(snapshot.weeklyWindow == nil, "non-weekly data must not be relabelled")
}

func testPreservesFractionalWeeklyUsage() {
    let snapshot = CodexRateLimitParser.parse(
        result: [
            "rateLimits": [
                "primary": ["usedPercent": 0.9, "windowDurationMins": 10_080, "resetsAt": 1_788_299_735]
            ]
        ],
        fetchedAt: Date(timeIntervalSince1970: 1_788_270_000)
    )
    expect(snapshot.weeklyWindow?.usedPercent == 0.9, "fractional usage must not be rounded before forecasting")
    expect(snapshot.weeklyWindow?.remainingPercent == 99.1, "fractional remaining quota must stay exact")
}

func testBuildsWeeklyDisplayModel() {
    let forecast = WeeklyRunwayForecast(
        state: .watch,
        confidence: .high,
        usedPercent: 42,
        remainingPercent: 58,
        elapsedPercent: 50,
        daysUntilReset: 3.5,
        sustainableRatePerDay: 15,
        recentRateBandPerDay: PaceBand(lower: 16, upper: 19),
        cycleRateBandPerDay: PaceBand(lower: 14, upper: 18),
        projectedRemainingBandAtReset: PercentageBand(lower: 8, upper: 17),
        estimatedEmptyAtRange: nil,
        next24HourBudget: 15
    )
    let model = CapsuleDisplayModel.make(forecast: forecast)
    expect(model.tone == .watch, "watch forecast should use watch tone")
    expect(model.defaultText.contains("8%–17%"), "display should expose a projection band")
    expect(model.metrics.count == 4, "weekly display should keep four decision metrics")
    expect(
        model.metrics.map(\.label) == ["本周时间", "本周已用", "最近 24 小时", "未来 24 小时建议"],
        "metric hierarchy should be weekly-only"
    )
}

final class FakeCodexTransport: CodexRPCTransport {
    private var responses: [[String: Any]]
    private(set) var sent: [[String: Any]] = []

    init(responses: [[String: Any]]) {
        self.responses = responses
    }

    func send(_ payload: [String: Any]) throws {
        sent.append(payload)
    }

    func readMessage(timeoutSeconds: TimeInterval) throws -> [String: Any] {
        guard !responses.isEmpty else {
            throw CodexAppServerError.transport("no fake response queued")
        }
        return responses.removeFirst()
    }

    func close() {}
}

func testAppServerReadsWeeklyQuotaAcrossNotifications() {
    let transport = FakeCodexTransport(responses: [
        ["jsonrpc": "2.0", "method": "window/logMessage", "params": [:]],
        ["jsonrpc": "2.0", "id": 1, "result": ["capabilities": [:]]],
        ["jsonrpc": "2.0", "id": 2, "result": [
            "rateLimits": [
                "primary": ["usedPercent": 62, "windowDurationMins": 300, "resetsAt": 1_788_271_414],
                "secondary": ["usedPercent": 24, "windowDurationMins": 10_080, "resetsAt": 1_788_299_735]
            ]
        ]]
    ])
    let snapshot = CodexAppServerClient.fetchSnapshot(
        transport: transport,
        fetchedAt: Date(timeIntervalSince1970: 1_788_270_000)
    )
    expect(snapshot.sourceStatus == .ok, "app-server snapshot should be successful")
    expect(snapshot.weeklyWindow?.usedPercent == 24, "app-server should select weekly usage")
    expect(
        transport.sent.compactMap { $0["method"] as? String } == ["initialize", "initialized", "account/rateLimits/read"],
        "JSON-RPC method order should stay stable"
    )
}

func testRetryPolicyAndPreference() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let valid = weeklySnapshot(fetchedAt: now)
    let timeout = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: now,
        weeklyWindow: nil,
        errorMessage: "codex app-server 读取超时。"
    )
    let auth = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: now,
        weeklyWindow: nil,
        errorMessage: "not signed in"
    )
    expect(!CodexAppServerClient.shouldRetry(valid), "valid weekly data should not trigger redundant probes")
    expect(CodexAppServerClient.shouldRetry(timeout), "transient timeouts should retry")
    expect(!CodexAppServerClient.shouldRetry(auth), "authentication failures should not loop")
    expect(
        CodexAppServerClient.preferredRetrySnapshot(current: valid, candidate: timeout) == valid,
        "a trailing failure must not erase a successful weekly result"
    )
}

func testRefreshReducerFreezesLastSuccessOnFailure() {
    let fetchedAt = Date(timeIntervalSince1970: 1_788_270_000)
    let current = weeklySnapshot(fetchedAt: fetchedAt, usedPercent: 25)
    let failure = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: fetchedAt.addingTimeInterval(60),
        weeklyWindow: nil,
        errorMessage: "failed to fetch codex rate limits: error sending request for url (https://example.invalid/secret)"
    )
    let reduction = QuotaRefreshReducer.reduce(
        currentSnapshot: current,
        currentLastRefreshText: "11:59:00",
        newSnapshot: failure,
        now: failure.fetchedAt,
        attemptText: "12:00:00"
    )
    expect(reduction.snapshot.sourceStatus == .stale, "failure after success should be visibly stale")
    expect(reduction.snapshot.weeklyWindow == current.weeklyWindow, "stale state should freeze the last successful weekly values")
    expect(reduction.lastRefreshText == "11:59:00", "failure must not claim a new success time")
    expect(reduction.lastAttemptText == "12:00:00", "failure should retain the attempt time")
    expect(reduction.lastErrorText?.contains("example.invalid") == false, "diagnostics must redact remote URLs")
}

func testExecutableResolverSearchesGuiSafePaths() throws {
    let resolved = try CodexExecutableResolver.resolveCandidate(
        environmentPath: "/usr/bin:/bin",
        homeDirectory: "/Users/example",
        isExecutable: { $0 == "/Users/example/.local/bin/codex" }
    )
    expect(resolved == "/Users/example/.local/bin/codex", "GUI launch should find the user-local Codex executable")
}

func testWeeklyHistoryMigrationSQLIsIdempotent() {
    var database: OpaquePointer?
    expect(sqlite3_open(":memory:", &database) == SQLITE_OK, "migration spec should open SQLite")
    defer { sqlite3_close(database) }

    func execute(_ sql: String) {
        expect(sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK, "migration SQL should execute: \(sql)")
    }

    func scalarInt(_ sql: String) -> Int {
        var statement: OpaquePointer?
        expect(sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, "scalar query should prepare")
        defer { sqlite3_finalize(statement) }
        expect(sqlite3_step(statement) == SQLITE_ROW, "scalar query should return a row")
        return Int(sqlite3_column_int(statement, 0))
    }

    execute("CREATE TABLE captures (id INTEGER PRIMARY KEY)")
    execute("""
    CREATE TABLE quota_windows (
      id INTEGER PRIMARY KEY, capture_id INTEGER NOT NULL, window_type TEXT NOT NULL,
      time_elapsed_percent INTEGER, burn_rate_percent_per_min REAL,
      burn_rate_vs_even_pace REAL, projected_remaining_at_reset INTEGER,
      estimated_empty_at REAL, used_delta_percent REAL, delta_minutes REAL,
      delta_percent_per_min REAL, reset_detected INTEGER NOT NULL DEFAULT 0
    )
    """)
    execute("INSERT INTO captures (id) VALUES (1), (2)")
    execute("""
    INSERT INTO quota_windows (
      id, capture_id, window_type, time_elapsed_percent,
      burn_rate_percent_per_min, burn_rate_vs_even_pace,
      projected_remaining_at_reset, estimated_empty_at,
      used_delta_percent, delta_minutes, delta_percent_per_min, reset_detected
    ) VALUES
      (1, 1, '5h', 25, 1, 2, 3, 4, 5, 6, 7, 1),
      (2, 2, 'weekly', 25, 1, 2, 3, 4, 5, 6, 7, 1)
    """)

    for _ in 0..<2 {
        execute("BEGIN IMMEDIATE TRANSACTION")
        WeeklyHistoryMigration.cleanupStatements.forEach(execute)
        execute("COMMIT")
    }

    expect(scalarInt("PRAGMA user_version") == 3, "migration should set schema version 3")
    expect(scalarInt("SELECT COUNT(*) FROM quota_windows WHERE window_type = '5h'") == 0, "migration should purge legacy rows")
    expect(scalarInt("SELECT COUNT(*) FROM quota_windows WHERE window_type = 'weekly'") == 1, "migration should preserve weekly rows")
    expect(
        scalarInt("SELECT COUNT(*) FROM quota_windows WHERE window_type = 'weekly' AND burn_rate_percent_per_min IS NULL AND projected_remaining_at_reset IS NULL AND reset_detected = 0") == 1,
        "migration should erase legacy derived fields"
    )
    expect(scalarInt("SELECT COUNT(*) FROM captures") == 1, "migration should remove orphaned captures")
}

do {
    try testParsesOnlyTheWeeklyWindow()
    testRejectsPayloadWithoutWeeklyWindow()
    testPreservesFractionalWeeklyUsage()
    testBuildsWeeklyDisplayModel()
    testAppServerReadsWeeklyQuotaAcrossNotifications()
    testRetryPolicyAndPreference()
    testRefreshReducerFreezesLastSuccessOnFailure()
    try testExecutableResolverSearchesGuiSafePaths()
    testWeeklyHistoryMigrationSQLIsIdempotent()
    print("QuotaCapsuleCoreSpec passed")
} catch {
    fputs("Spec failed with error: \(error)\n", stderr)
    exit(1)
}
