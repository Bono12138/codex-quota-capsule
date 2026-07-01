import Foundation
import QuotaCapsuleCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Spec failed: \(message)\n", stderr)
        exit(1)
    }
}

func testParsesCodexRateLimitsByDuration() throws {
    let result = """
    {
      "rateLimits": {
        "primary": { "usedPercent": 41, "windowDurationMins": 10080, "resetsAt": 1788299735 },
        "secondary": { "usedPercent": 17, "windowDurationMins": 300, "resetsAt": 1788271414 }
      }
    }
    """.data(using: .utf8)!

    let snapshot = try CodexRateLimitParser.parse(resultData: result, fetchedAt: Date(timeIntervalSince1970: 1_788_270_000))

    expect(snapshot.provider == "codex", "provider should be codex")
    expect(snapshot.sourceStatus == .ok, "source status should be ok")
    expect(snapshot.shortWindow?.label == "5h", "short window should be 5h")
    expect(snapshot.shortWindow?.usedPercent == 17, "short window used percent should come from 300 minute window")
    expect(snapshot.weeklyWindow?.label == "weekly", "weekly window should be weekly")
    expect(snapshot.weeklyWindow?.usedPercent == 41, "weekly used percent should come from 10080 minute window")
}

func testPredictsBurnRateRunway() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let snapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 20,
            remainingPercent: 80,
            resetsAt: now.addingTimeInterval(120 * 60)
        ),
        weeklyWindow: nil,
        errorMessage: nil
    )

    let prediction = QuotaPredictor.predict(snapshot: snapshot, now: now)

    expect(prediction.level == .safe, "prediction should be safe")
    expect(prediction.quotaUsedPercent == 20, "quota used percent should be 20")
    expect(prediction.elapsedPercent == 60, "elapsed percent should be 60")
    expect(prediction.projectedRemainingAtReset == 67, "projected remaining should be rounded to 67")
    expect(prediction.headline.contains("够用到"), "headline should be human-readable runway copy")
}

func testBuildsCompactDisplayModel() {
    let prediction = CapsulePrediction(
        level: .danger,
        canReachReset: false,
        elapsedPercent: 70,
        quotaUsedPercent: 95,
        projectedRemainingAtReset: 0,
        estimatedEmptyAt: Date(timeIntervalSince1970: 1_788_271_800),
        headline: "按当前速度，预计 14:30 用完",
        detail: "撑不到 15:00 刷新。"
    )

    let model = CapsuleDisplayModel.make(prediction: prediction)

    expect(model.statusLabel == "危险", "danger label should be localized")
    expect(model.defaultText.contains("见底"), "danger compact text should mention bottoming out")
    expect(model.metrics.map(\.label) == ["时间进度", "额度已用", "当前速度", "刷新余量"], "metrics should preserve compact detail order")
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

func testCodexAppServerClientReadsRateLimits() throws {
    let transport = FakeCodexTransport(responses: [
        ["jsonrpc": "2.0", "method": "window/logMessage", "params": [:]],
        ["jsonrpc": "2.0", "id": 1, "result": ["capabilities": [:]]],
        ["jsonrpc": "2.0", "id": 2, "result": [
            "rateLimits": [
                "primary": ["usedPercent": 62, "windowDurationMins": 300, "resetsAt": 1_788_271_414],
                "secondary": ["usedPercent": 24, "windowDurationMins": 10080, "resetsAt": 1_788_299_735]
            ]
        ]]
    ])

    let snapshot = CodexAppServerClient.fetchSnapshot(
        transport: transport,
        fetchedAt: Date(timeIntervalSince1970: 1_788_270_000)
    )

    expect(snapshot.sourceStatus == .ok, "app-server snapshot should be ok")
    expect(snapshot.shortWindow?.usedPercent == 62, "app-server should parse short window")
    expect(snapshot.weeklyWindow?.usedPercent == 24, "app-server should parse weekly window")
    expect(transport.sent.map { $0["method"] as? String } == ["initialize", "initialized", "account/rateLimits/read"], "app-server request order should be fixed")
}

func testCodexExecutableResolverFindsUserLocalBin() throws {
    let resolved = try CodexExecutableResolver.resolveCandidate(
        environmentPath: "/usr/bin:/bin",
        homeDirectory: "/Users/example",
        isExecutable: { path in
            path == "/Users/example/.local/bin/codex"
        }
    )

    expect(resolved == "/Users/example/.local/bin/codex", "resolver should check ~/.local/bin/codex for GUI app launches")
}

do {
    try testParsesCodexRateLimitsByDuration()
    testPredictsBurnRateRunway()
    testBuildsCompactDisplayModel()
    try testCodexAppServerClientReadsRateLimits()
    try testCodexExecutableResolverFindsUserLocalBin()
    print("QuotaCapsuleCoreSpec passed")
} catch {
    fputs("Spec failed with error: \(error)\n", stderr)
    exit(1)
}
