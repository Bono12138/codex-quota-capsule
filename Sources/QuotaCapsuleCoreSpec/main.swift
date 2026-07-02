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

func testPredictsExhaustedShortWindowAsDanger() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let snapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 100,
            remainingPercent: 0,
            resetsAt: now.addingTimeInterval(90 * 60)
        ),
        weeklyWindow: nil,
        errorMessage: nil
    )

    let prediction = QuotaPredictor.predict(snapshot: snapshot, now: now)

    expect(prediction.level == .danger, "exhausted short window should be danger")
    expect(prediction.canReachReset == false, "exhausted short window cannot reach reset")
    expect(prediction.quotaUsedPercent == 100, "exhausted short window should report 100 percent used")
}

func testPredictsExhaustedWeeklyWindowAsDanger() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let snapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 10,
            remainingPercent: 90,
            resetsAt: now.addingTimeInterval(180 * 60)
        ),
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10080,
            usedPercent: 100,
            remainingPercent: 0,
            resetsAt: now.addingTimeInterval(24 * 60 * 60)
        ),
        errorMessage: nil
    )

    let prediction = QuotaPredictor.predict(snapshot: snapshot, now: now)

    expect(prediction.level == .danger, "exhausted weekly window should be danger")
    expect(prediction.detail.contains("weekly"), "weekly exhaustion should identify the exhausted window")
}

func testPredictsMissingShortWindowAsUnknownWhenWeeklyIsNotExhausted() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let snapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10080,
            usedPercent: 40,
            remainingPercent: 60,
            resetsAt: now.addingTimeInterval(24 * 60 * 60)
        ),
        errorMessage: nil
    )

    let prediction = QuotaPredictor.predict(snapshot: snapshot, now: now)

    expect(prediction.level == .unknown, "missing short window should remain unknown when weekly is not exhausted")
}

func testWeeklyPredictionUsesWeeklyWindowInputsOnly() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let snapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 90,
            remainingPercent: 10,
            resetsAt: now.addingTimeInterval(30 * 60)
        ),
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 10,
            remainingPercent: 90,
            resetsAt: now.addingTimeInterval(5_040 * 60)
        ),
        errorMessage: nil
    )

    let prediction = QuotaPredictor.predictWeekly(snapshot: snapshot, now: now)

    expect(prediction?.level == .safe, "weekly prediction should be safe when weekly pace is safe even if 5h is hot")
    expect(prediction?.quotaUsedPercent == 10, "weekly prediction numerator must use weekly usedPercent")
    expect(prediction?.elapsedPercent == 50, "weekly prediction denominator must use weekly windowMinutes and resetsAt")
    expect(prediction?.projectedRemainingAtReset == 80, "weekly projected remaining should use weekly pace only")
}

func testPredictsExpiredResetAsUnknown() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let snapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 100,
            remainingPercent: 0,
            resetsAt: now.addingTimeInterval(-60)
        ),
        weeklyWindow: nil,
        errorMessage: nil
    )

    let prediction = QuotaPredictor.predict(snapshot: snapshot, now: now)

    expect(prediction.level == .unknown, "expired reset should remain unknown even with stale exhausted values")
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
    expect(model.compactDetail == "95%", "compact detail should expose used percentage")
    expect(model.defaultText.contains("见底"), "danger compact text should mention bottoming out")
    expect(model.metrics.map(\.label) == ["时间进度", "额度已用", "当前速度", "刷新余量"], "metrics should preserve compact detail order")
}

func testQuotaLocaleResolvesPreferredLanguages() {
    expect(QuotaLocale.current(preferredLanguages: ["zh-Hant-HK"]) == .zhHant, "Traditional Chinese HK should resolve to zh-Hant")
    expect(QuotaLocale.current(preferredLanguages: ["zh-Hant-TW"]) == .zhHant, "Traditional Chinese TW should resolve to zh-Hant")
    expect(QuotaLocale.current(preferredLanguages: ["zh-Hans-CN"]) == .zhHans, "Simplified Chinese should resolve to zh-Hans")
    expect(QuotaLocale.current(preferredLanguages: ["en-US"]) == .en, "English should resolve to en")
    expect(QuotaLocale.supported(preferredLanguages: ["fr-FR"]) == nil, "unsupported languages should trigger first-run language selection")
}

func testContactCopyIncludesDouyinInAllLocales() {
    expect(QuotaCopy(locale: .zhHans).douyinLine.contains("huotuichang439"), "Simplified Chinese contact copy should include Douyin ID")
    expect(QuotaCopy(locale: .zhHant).copyDouyinIdAction == "huotuichang439", "Douyin copy action should show the ID directly")
    expect(QuotaCopy(locale: .en).douyinQrHint.contains("Douyin"), "English QR hint should name Douyin")
    expect(QuotaCopy(locale: .zhHans).openDouyinAction == "打开抖音", "Douyin primary action should open Douyin")
}

func testRuntimeLocaleCopyCoversMenuOnboardingAndConsent() {
    for locale in [QuotaLocale.zhHans, .zhHant, .en] {
        let copy = QuotaCopy(locale: locale)
        expect(!copy.languageMenuTitle.isEmpty, "language menu title should be localized")
        expect(copy.languageMenuTitle.contains("Language"), "language menu title should be findable by English readers")
        expect(!copy.authorMenuHint.isEmpty, "menu author teaser should be localized")
        expect(!copy.onboardingAuthorIntro.isEmpty, "onboarding author intro should be localized")
        expect(!copy.productIntroBody.isEmpty, "product intro should be localized")
        expect(!copy.betaThanksBody.isEmpty, "beta thanks copy should be localized")
        expect(copy.currentVersionFeatures.count >= 4, "current version feature list should stay populated")
        expect(copy.futureVersionFeatures.count >= 3, "future feature list should stay populated")
        expect(!copy.releaseUpdateReminder.isEmpty, "release update reminder should be localized")
        expect(!copy.contactAuthorTitle.isEmpty, "contact author title should be localized")
        expect(!copy.resizeCapsuleHelp.isEmpty, "resize help should be localized")
        expect(!copy.compactUsageTrackLabel.isEmpty, "compact usage track label should be localized")
        expect(!copy.analyticsBasicSummaryText.isEmpty, "basic analytics summary should be localized")
        expect(!copy.advancedDataSettingsTitle.isEmpty, "advanced data settings title should be localized")
        expect(!copy.localDataPrivacyAuthorizationTitle.isEmpty, "local data privacy title should be localized")
        expect(!copy.analyticsRevokeAction.isEmpty, "analytics revoke action should be localized")
        expect(!copy.keepParticipatingAction.isEmpty, "analytics revoke retention action should be localized")
        expect(!copy.keepLocalHistoryAction.isEmpty, "local history retention action should be localized")
        expect(!copy.confirmRevokeAnalyticsMessage.isEmpty, "analytics revoke confirmation should be localized")
        expect(!copy.confirmClearLocalHistoryMessage.isEmpty, "clear local history confirmation should be localized")
        expect(!copy.analyticsSensitiveBoundary.contains("不会"), "Simplified analytics boundary should use affirmative copy")
        expect(!copy.analyticsSensitiveBoundary.contains("不會"), "Traditional analytics boundary should use affirmative copy")
        expect(!copy.analyticsSensitiveBoundary.lowercased().contains("does not"), "English analytics boundary should use affirmative copy")
    }
    expect(QuotaCopy(locale: .zhHans).analyticsRevokeAction == "不参与产品改进计划", "Simplified revoke action should use user-approved wording")
}

func testLocalizedUnknownAndParserDiagnostics() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let sourceErrorPrediction = QuotaPredictor.predict(
        snapshot: AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .error,
            fetchedAt: now,
            shortWindow: nil,
            weeklyWindow: nil,
            errorMessage: nil
        ),
        now: now,
        locale: .zhHant
    )
    expect(sourceErrorPrediction.detail.contains("資料來源"), "Traditional source-unavailable detail should be localized")

    let missingShortPrediction = QuotaPredictor.predict(
        snapshot: AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .ok,
            fetchedAt: now,
            shortWindow: nil,
            weeklyWindow: QuotaWindow(
                label: "weekly",
                windowMinutes: 10_080,
                usedPercent: 10,
                remainingPercent: 90,
                resetsAt: now.addingTimeInterval(5_040 * 60)
            ),
            errorMessage: nil
        ),
        now: now,
        locale: .en
    )
    expect(missingShortPrediction.detail.contains("5-hour"), "English missing-short-window detail should be localized")

    let expiredPrediction = QuotaPredictor.predict(
        snapshot: AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .ok,
            fetchedAt: now,
            shortWindow: QuotaWindow(
                label: "5h",
                windowMinutes: 300,
                usedPercent: 20,
                remainingPercent: 80,
                resetsAt: now.addingTimeInterval(-60)
            ),
            weeklyWindow: nil,
            errorMessage: nil
        ),
        now: now,
        locale: .zhHans
    )
    expect(expiredPrediction.detail.contains("重新读取"), "Simplified expired-reset detail should be localized")

    let malformed = CodexRateLimitParser.parse(result: ["rateLimits": [:]], fetchedAt: now, locale: .zhHant)
    expect(malformed.errorMessage?.contains("額度週期") == true, "Traditional parser error should be localized")
}

func testOnboardingCopyAvoidsAccountManagerNegation() {
    for locale in [QuotaLocale.zhHans, .zhHant, .en] {
        let copy = QuotaCopy(locale: locale)
        expect(!copy.onboardingSubtitle.contains("账号管理"), "Simplified onboarding should not mention account manager")
        expect(!copy.onboardingSubtitle.contains("帳號管理"), "Traditional onboarding should not mention account manager")
        expect(!copy.onboardingSubtitle.lowercased().contains("account manager"), "English onboarding should not mention account manager")
        expect(!copy.onboardingPrivacyAction.contains("隐私说明"), "Privacy copy should not be hidden behind a low-value button")
        expect(!copy.onboardingPrivacyAction.contains("隱私說明"), "Traditional privacy copy should not be hidden behind a low-value button")
        expect(!copy.onboardingPrivacyAction.lowercased().contains("privacy note"), "English privacy copy should not be hidden behind a low-value button")
    }
}

func testBuildsEnglishDisplayModel() {
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
    let prediction = QuotaPredictor.predict(snapshot: snapshot, now: now, locale: .en)
    let model = CapsuleDisplayModel.make(prediction: prediction, locale: .en)

    expect(model.statusLabel == "Safe", "English status label should be localized")
    expect(model.metrics.map(\.label) == ["Time elapsed", "Quota used", "Current pace", "Reset buffer"], "English metrics should be localized")
    expect(prediction.headline.lowercased().contains("quota lasts"), "English prediction headline should be localized")
    expect(model.defaultText.hasPrefix("Until "), "English compact text should shorten the safe headline")
}

func testBuildsTraditionalChineseDisplayModel() {
    let prediction = CapsulePrediction(
        level: .danger,
        canReachReset: false,
        elapsedPercent: 70,
        quotaUsedPercent: 95,
        projectedRemainingAtReset: 0,
        estimatedEmptyAt: Date(timeIntervalSince1970: 1_788_271_800),
        headline: "依目前速度，預計 14:30 用完",
        detail: "撐不到 15:00 重設。"
    )
    let model = CapsuleDisplayModel.make(prediction: prediction, locale: .zhHant)

    expect(model.statusLabel == "危險", "Traditional Chinese danger label should be localized")
    expect(model.defaultText.contains("見底"), "Traditional Chinese compact danger text should be localized")
    expect(model.metrics.map(\.label) == ["時間進度", "額度已用", "目前速度", "重設餘量"], "Traditional Chinese metrics should be localized")
}

func testCompactCopyStaysShortAcrossLocales() {
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

    for locale in [QuotaLocale.zhHans, .zhHant, .en] {
        let prediction = QuotaPredictor.predict(snapshot: snapshot, now: now, locale: locale)
        let model = CapsuleDisplayModel.make(prediction: prediction, locale: locale)

        expect(model.statusLabel.count <= 8, "compact status label should stay short in \(locale)")
        expect(model.defaultText.count <= 24, "compact projection text should stay short in \(locale)")
    }
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

final class ThrowingCodexTransport: CodexRPCTransport {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func send(_ payload: [String: Any]) throws {}

    func readMessage(timeoutSeconds: TimeInterval) throws -> [String: Any] {
        throw error
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

func testCodexAppServerClientReturnsRpcErrors() {
    let transport = FakeCodexTransport(responses: [
        ["jsonrpc": "2.0", "id": 1, "result": ["capabilities": [:]]],
        ["jsonrpc": "2.0", "id": 2, "error": ["code": -32000, "message": "not signed in"]]
    ])

    let snapshot = CodexAppServerClient.fetchSnapshot(
        transport: transport,
        fetchedAt: Date(timeIntervalSince1970: 1_788_270_000)
    )

    expect(snapshot.sourceStatus == .error, "app-server RPC errors should return error snapshots")
    expect(snapshot.errorMessage?.contains("not signed in") == true, "app-server RPC error should preserve useful message")
}

func testCodexAppServerClientReturnsTransportErrors() {
    let transport = ThrowingCodexTransport(error: CodexAppServerError.transport("codex app-server 读取超时。"))

    let snapshot = CodexAppServerClient.fetchSnapshot(
        transport: transport,
        fetchedAt: Date(timeIntervalSince1970: 1_788_270_000)
    )

    expect(snapshot.sourceStatus == .error, "app-server transport errors should return error snapshots")
    expect(snapshot.errorMessage?.contains("读取超时") == true, "transport errors should preserve timeout message")
}

func testCodexRateLimitParserRejectsMalformedWindows() {
    let snapshot = CodexRateLimitParser.parse(
        result: [
            "rateLimits": [
                "primary": ["usedPercent": 50, "windowDurationMins": 300],
                "secondary": ["usedPercent": "bad", "windowDurationMins": 10080, "resetsAt": 1_788_299_735]
            ]
        ],
        fetchedAt: Date(timeIntervalSince1970: 1_788_270_000)
    )

    expect(snapshot.sourceStatus == .error, "malformed windows should return error snapshots when no usable window remains")
    expect(snapshot.shortWindow == nil, "malformed short window should not be parsed")
    expect(snapshot.errorMessage?.contains("rateLimits") == true, "malformed windows should explain missing usable rateLimits")
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

func testCodexExecutableResolverReportsCheckedPaths() {
    do {
        _ = try CodexExecutableResolver.resolveCandidate(
            environmentPath: "/custom/bin:/opt/homebrew/bin",
            homeDirectory: "/Users/example",
            isExecutable: { _ in false }
        )
        expect(false, "resolver should fail when no candidate is executable")
    } catch let error as CodexAppServerError {
        guard case .missingExecutable(let candidates) = error else {
            expect(false, "resolver should return a missing executable error")
            return
        }

        let description = String(describing: error)
        expect(candidates.contains("/Users/example/.local/bin/codex"), "missing executable should include user local candidate")
        expect(candidates.contains("/custom/bin/codex"), "missing executable should include PATH candidate")
        expect(candidates.filter { $0 == "/opt/homebrew/bin/codex" }.count == 1, "candidate list should deduplicate explicit and PATH candidates")
        expect(description.contains("App 已检查"), "missing executable description should explain checked paths")
        expect(description.contains("which codex"), "missing executable description should include terminal repair command")
        expect(error.message(locale: .en).contains("Could not find"), "missing executable should have English diagnostic copy")
        expect(error.message(locale: .zhHant).contains("已檢查"), "missing executable should have Traditional Chinese diagnostic copy")
    } catch {
        expect(false, "resolver should fail with CodexAppServerError")
    }
}

func testQuotaRefreshReducerUpdatesOnSuccessfulRefresh() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let currentSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: now.addingTimeInterval(-60),
        shortWindow: nil,
        weeklyWindow: nil,
        errorMessage: "启动中"
    )
    let newSnapshot = AgentQuotaSnapshot(
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

    let reduction = QuotaRefreshReducer.reduce(
        currentSnapshot: currentSnapshot,
        currentLastRefreshText: "尚未刷新",
        newSnapshot: newSnapshot,
        now: now,
        attemptText: "12:00:00"
    )

    expect(reduction.snapshot == newSnapshot, "successful refresh should replace snapshot")
    expect(reduction.lastRefreshText == "12:00:00", "successful refresh should update last success text")
    expect(reduction.lastAttemptText == "12:00:00", "successful refresh should update last attempt text")
    expect(reduction.lastErrorText == nil, "successful refresh should clear previous errors")
}

func testQuotaRefreshReducerPreservesLastSuccessAfterFailure() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let currentSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now.addingTimeInterval(-60),
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
    let failedSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: nil,
        errorMessage: "codex app-server 读取超时。\nretry later"
    )

    let reduction = QuotaRefreshReducer.reduce(
        currentSnapshot: currentSnapshot,
        currentLastRefreshText: "11:59:00",
        newSnapshot: failedSnapshot,
        now: now,
        attemptText: "12:00:00"
    )

    expect(reduction.snapshot == currentSnapshot, "refresh failure should keep last successful snapshot")
    expect(reduction.prediction.level == .safe, "refresh failure should recompute prediction from last successful snapshot")
    expect(reduction.lastRefreshText == "11:59:00", "refresh failure should preserve last success time")
    expect(reduction.lastAttemptText == "12:00:00", "refresh failure should update last attempt time")
    expect(reduction.lastErrorText?.contains("读取超时") == true, "refresh failure should keep readable error")
    expect(reduction.lastErrorText?.contains("\n") == false, "refresh failure error should be compressed to one line")
}

func testQuotaRefreshReducerUsesErrorWhenNoSuccessExists() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let currentSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: now.addingTimeInterval(-60),
        shortWindow: nil,
        weeklyWindow: nil,
        errorMessage: "启动中"
    )
    let failedSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: nil,
        errorMessage: "not signed in"
    )

    let reduction = QuotaRefreshReducer.reduce(
        currentSnapshot: currentSnapshot,
        currentLastRefreshText: "尚未刷新",
        newSnapshot: failedSnapshot,
        now: now,
        attemptText: "12:00:00"
    )

    expect(reduction.snapshot == failedSnapshot, "first refresh failure should use error snapshot")
    expect(reduction.prediction.level == .unknown, "first refresh failure should be unknown")
    expect(reduction.lastRefreshText == "尚未刷新", "first refresh failure should not claim a successful refresh")
    expect(reduction.lastErrorText == "not signed in", "first refresh failure should preserve readable error")
}

func testCodexAppServerClientDefaultTimeoutIsProductionTolerant() {
    expect(CodexAppServerClient.defaultTimeoutSeconds >= 30, "default app-server timeout should tolerate Codex startup sync work")
}

do {
    try testParsesCodexRateLimitsByDuration()
    testPredictsBurnRateRunway()
    testPredictsExhaustedShortWindowAsDanger()
    testPredictsExhaustedWeeklyWindowAsDanger()
    testPredictsMissingShortWindowAsUnknownWhenWeeklyIsNotExhausted()
    testWeeklyPredictionUsesWeeklyWindowInputsOnly()
    testPredictsExpiredResetAsUnknown()
    testBuildsCompactDisplayModel()
    testQuotaLocaleResolvesPreferredLanguages()
    testContactCopyIncludesDouyinInAllLocales()
    testRuntimeLocaleCopyCoversMenuOnboardingAndConsent()
    testLocalizedUnknownAndParserDiagnostics()
    testOnboardingCopyAvoidsAccountManagerNegation()
    testBuildsEnglishDisplayModel()
    testBuildsTraditionalChineseDisplayModel()
    testCompactCopyStaysShortAcrossLocales()
    try testCodexAppServerClientReadsRateLimits()
    testCodexAppServerClientReturnsRpcErrors()
    testCodexAppServerClientReturnsTransportErrors()
    testCodexRateLimitParserRejectsMalformedWindows()
    try testCodexExecutableResolverFindsUserLocalBin()
    testCodexExecutableResolverReportsCheckedPaths()
    testQuotaRefreshReducerUpdatesOnSuccessfulRefresh()
    testQuotaRefreshReducerPreservesLastSuccessAfterFailure()
    testQuotaRefreshReducerUsesErrorWhenNoSuccessExists()
    testCodexAppServerClientDefaultTimeoutIsProductionTolerant()
    print("QuotaCapsuleCoreSpec passed")
} catch {
    fputs("Spec failed with error: \(error)\n", stderr)
    exit(1)
}
