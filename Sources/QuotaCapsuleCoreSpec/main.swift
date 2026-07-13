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

func testTreatsWeeklyOnlyRateLimitsAsWaitingForTheNextShortWindow() {
    let snapshot = CodexRateLimitParser.parse(
        result: [
            "rateLimits": [
                "primary": [
                    "usedPercent": 10,
                    "windowDurationMins": 10_080,
                    "resetsAt": 1_788_299_735
                ]
            ]
        ],
        fetchedAt: Date(timeIntervalSince1970: 1_788_270_000)
    )

    expect(snapshot.sourceStatus == .ok, "weekly-only payload can be the valid idle state between 5-hour windows")
    expect(snapshot.shortWindow == nil, "idle payload should not invent a short window")
    expect(snapshot.weeklyWindow?.usedPercent == 10, "current weekly context should remain visible while idle")
    expect(snapshot.errorMessage == nil, "a valid idle payload should not carry a source error")
    expect(CodexAppServerClient.shouldRetry(snapshot), "weekly-only payload should still be retried before accepting idle")
    expect(!CodexAppServerClient.shouldRetry(snapshot, retryWeeklyOnly: false), "an idle caller should accept weekly-only data without extra probes")

    let prediction = QuotaPredictor.predict(snapshot: snapshot, now: snapshot.fetchedAt)
    let display = CapsuleDisplayModel.make(prediction: prediction)
    expect(prediction.level == .unknown, "idle state should not make a risk claim")
    expect(prediction.headline.contains("等待新的 5 小时窗口"), "idle state should explicitly say it is waiting for a new window")
    expect(prediction.detail.contains("开始使用 Codex"), "idle state should explain what makes the window appear")
    expect(display.statusLabel == "待开始", "idle state should not be labelled unknown or stale")
    expect(display.metrics.allSatisfy { $0.value == "待开始" }, "inactive 5-hour metrics should say waiting instead of unknown")
    expect(
        QuotaCopy(locale: .zhHans).weeklyProjectionWillLast(usedPercent: 0, projectedRemaining: 79).contains("低于 1%"),
        "weekly zero reports should use below-precision wording instead of claiming exact zero usage"
    )
}

func testRetryKeepsTheMostCompleteSnapshotAcrossAttempts() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let weeklyOnly = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 0,
            remainingPercent: 100,
            resetsAt: now.addingTimeInterval(10_000 * 60)
        ),
        errorMessage: nil
    )
    let emptyFailure = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: now.addingTimeInterval(1),
        shortWindow: nil,
        weeklyWindow: nil,
        errorMessage: "rateLimits did not include any usable windows"
    )
    let full = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now.addingTimeInterval(2),
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 1,
            remainingPercent: 99,
            resetsAt: now.addingTimeInterval(300 * 60)
        ),
        weeklyWindow: weeklyOnly.weeklyWindow,
        errorMessage: nil
    )

    expect(CodexAppServerClient.shouldRetry(emptyFailure), "an empty rateLimits response can be transient and should be retried")
    expect(
        CodexAppServerClient.preferredRetrySnapshot(current: weeklyOnly, candidate: emptyFailure) == weeklyOnly,
        "a trailing empty response must not erase a valid weekly-only retry result"
    )
    expect(
        CodexAppServerClient.preferredRetrySnapshot(current: weeklyOnly, candidate: full) == full,
        "a complete short-window response should replace weekly-only data"
    )
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

func testFractionalUsageStaysConsistentInDisplayMath() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let prediction = QuotaPredictor.predict(
        window: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 1.9,
            remainingPercent: 98.1,
            resetsAt: now.addingTimeInterval(120 * 60)
        ),
        now: now
    )
    let model = CapsuleDisplayModel.make(prediction: prediction)

    expect(prediction.quotaUsedPercent == 1, "progress bars may use the floored integer percent")
    expect(prediction.quotaUsedPercentExact == 1.9, "prediction should retain exact usage for display math")
    expect(model.compactDetail == "1.9%", "compact display should preserve fractional usage")
    expect(model.metrics.first { $0.label == "额度已用" }?.value == "1.9%", "usage metric should preserve fractional usage")
    expect(model.metrics.first { $0.label == "当前速度" }?.value == "0.03x", "pace should use exact usage rather than the floored integer")
}

func testPredictsBelowReportingPrecisionConservatively() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let snapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 0,
            remainingPercent: 100,
            resetsAt: now.addingTimeInterval(120 * 60)
        ),
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 0,
            remainingPercent: 100,
            resetsAt: now.addingTimeInterval(5_040 * 60)
        ),
        errorMessage: nil
    )

    let prediction = QuotaPredictor.predict(snapshot: snapshot, now: now)

    expect(prediction.level == .safe, "a below-precision reading late in the window should be safe")
    expect(prediction.canReachReset == true, "the conservative upper bound can reach reset")
    expect(prediction.quotaUsedPercent == 0, "the numeric progress remains the reported integer percent")
    expect(prediction.projectedRemainingAtReset == 98, "zero should use a conservative less-than-one-percent upper bound")
    expect(prediction.headline.contains("低于 1%"), "zero must not claim that the user has not started consuming quota")

    let model = CapsuleDisplayModel.make(prediction: prediction)
    expect(model.compactDetail == "<1%", "compact usage should expose reporting precision")
    expect(model.metrics.first { $0.label == "额度已用" }?.value == "<1%", "usage metric should expose reporting precision")
    expect(model.metrics.first { $0.label == "当前速度" }?.value.hasPrefix("<") == true, "zero pace should be presented as an upper bound")
}

func testPredictsBelowReportingPrecisionAsUnknownImmediatelyAfterReset() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let snapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 0,
            remainingPercent: 100,
            resetsAt: now.addingTimeInterval(299 * 60)
        ),
        weeklyWindow: nil,
        errorMessage: nil
    )

    let prediction = QuotaPredictor.predict(snapshot: snapshot, now: now)

    expect(prediction.level == .unknown, "a below-precision reading immediately after reset is not enough for a safe forecast")
    expect(prediction.canReachReset == nil, "an early below-precision reading has no reliable runway conclusion")
    expect(prediction.quotaUsedPercent == 0, "the source reading should remain visible during warmup")
    expect(prediction.projectedRemainingAtReset == nil, "warmup should not claim an exact full remaining quota")
    expect(prediction.headline.contains("低于 1%"), "warmup copy should describe reporting precision")
}

func testWindowStartBoundaryIsWarmupNotClockError() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let window = QuotaWindow(
        label: "5h",
        windowMinutes: 300,
        usedPercent: 0,
        remainingPercent: 100,
        resetsAt: now.addingTimeInterval(300 * 60)
    )

    let prediction = QuotaPredictor.predict(window: window, now: now)

    expect(prediction.level == .unknown, "the exact reset boundary should remain warmup")
    expect(!prediction.headline.contains("本地时间"), "the exact reset boundary is not a clock anomaly")
}

func testPredictorRejectsInvalidWindowWithoutTrapping() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let prediction = QuotaPredictor.predict(
        window: QuotaWindow(
            label: "broken",
            windowMinutes: 0,
            usedPercent: 1,
            remainingPercent: 99,
            resetsAt: now.addingTimeInterval(60)
        ),
        now: now
    )

    expect(prediction.level == .unknown, "invalid direct window input should be rejected without division or integer traps")
    expect(prediction.headline.contains("无效"), "invalid direct window input should have a clear diagnostic")
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

func testWeeklyPredictionWaitsForEnoughEarlyWindowSignal() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let snapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 57,
            remainingPercent: 43,
            resetsAt: now.addingTimeInterval(160 * 60)
        ),
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 1,
            remainingPercent: 99,
            resetsAt: now.addingTimeInterval((10_080 - 45) * 60)
        ),
        errorMessage: nil
    )

    let prediction = QuotaPredictor.predictWeekly(snapshot: snapshot, now: now)

    expect(prediction?.level == .unknown, "early weekly prediction should stay low-confidence")
    expect(prediction?.canReachReset == nil, "early weekly prediction should not claim a run-out time")
    expect(prediction?.quotaUsedPercent == 1, "early weekly prediction should still expose weekly used percent")
    expect(prediction?.estimatedEmptyAt == nil, "early weekly prediction should not extrapolate a false empty time")
    expect(prediction?.projectedRemainingAtReset == nil, "early weekly prediction should not project reset buffer")
}

func testWeeklyPredictionDoesNotEstimateExactRunOutAtFivePercentEarlyWindow() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let snapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 5,
            remainingPercent: 95,
            resetsAt: now.addingTimeInterval((10_080 - 55) * 60)
        ),
        errorMessage: nil
    )

    let prediction = QuotaPredictor.predictWeekly(snapshot: snapshot, now: now)

    expect(prediction?.level == .watch, "5% weekly usage very early should be watch-level pressure")
    expect(prediction?.canReachReset == nil, "5% weekly usage very early should not claim whether it reaches reset")
    expect(prediction?.quotaUsedPercent == 5, "early weekly watch should expose weekly used percent")
    expect(prediction?.estimatedEmptyAt == nil, "early weekly watch should not estimate an exact empty time")
    expect(prediction?.projectedRemainingAtReset == nil, "early weekly watch should not project reset buffer")
}

func testWeeklyPredictionFlagsFastEarlyBurnWithoutExactRunOutTime() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let snapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 8,
            remainingPercent: 92,
            resetsAt: now.addingTimeInterval((10_080 - 45) * 60)
        ),
        errorMessage: nil
    )

    let prediction = QuotaPredictor.predictWeekly(snapshot: snapshot, now: now)

    expect(prediction?.level == .watch, "material early weekly burn should be flagged without exact exhaustion")
    expect(prediction?.canReachReset == nil, "material early weekly burn should not claim whether it reaches reset")
    expect(prediction?.estimatedEmptyAt == nil, "material early weekly burn should not estimate an exact empty time")
    expect(prediction?.projectedRemainingAtReset == nil, "material early weekly burn should not project reset buffer")
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
        expect(!copy.currentVersionFeatures.joined(separator: " ").contains("二维码"), "current features should not treat contact QR as a product capability")
        expect(!copy.currentVersionFeatures.joined(separator: " ").contains("QR Code"), "current features should not treat contact QR as a product capability")
        expect(copy.futureVersionFeatures.count >= 3, "future feature list should stay populated")
        expect(!copy.aboutAuthorTitle.isEmpty, "about author title should be localized")
        expect(!copy.aboutAuthorBody.isEmpty, "about author body should be localized")
        expect(!copy.contactAuthorTitle.isEmpty, "contact author title should be localized")
        expect(!copy.authorProfileAction.isEmpty, "author profile action should be localized")
        expect(!copy.panelQuickActionsTitle.isEmpty, "panel quick actions title should be localized")
        expect(!copy.moreActionsTitle.isEmpty, "more actions title should be localized")
        expect(!copy.openStatusMenuAction.isEmpty, "open status menu action should be localized")
        expect(!copy.submitFeedbackAction.isEmpty, "unified submit feedback action should be localized")
        expect(!copy.feedbackAlternativeHint.isEmpty, "feedback alternative hint should be localized")
        expect(!copy.codexFeedbackAction.isEmpty, "Codex-assisted feedback action should be localized")
        expect(!copy.codexFeedbackCopiedAction.isEmpty, "Codex-assisted feedback copied action should be localized")
        expect(!copy.codexFeedbackHint.isEmpty, "Codex-assisted feedback hint should be localized")
        expect(!copy.assistedFeedbackStartedMessage.isEmpty, "assisted feedback GitHub message should be localized")
        expect(!copy.assistedFeedbackEmailMessage.isEmpty, "assisted feedback email message should be localized")
        expect(!copy.feedbackNudgeTitle.isEmpty, "feedback nudge title should be localized")
        expect(!copy.feedbackNudgeMessage.isEmpty, "feedback nudge message should be localized")
        expect(!copy.feedbackNudgeOpenAction.isEmpty, "feedback nudge open action should be localized")
        expect(!copy.feedbackNudgeCodexAction.isEmpty, "feedback nudge Codex action should be localized")
        expect(!copy.feedbackNudgeCopiedMessage.isEmpty, "feedback nudge copied message should be localized")
        expect(!copy.doneAction.isEmpty, "done action should be localized")
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
    expect(QuotaCopy(locale: .zhHans).authorProfileAction == "作者 X 主页", "X profile action should not be labelled as project home")
    expect(QuotaCopy(locale: .zhHans).submitFeedbackAction == "提交反馈", "Simplified feedback action should be unified")
    expect(QuotaCopy(locale: .zhHans).codexFeedbackCopiedAction != "已打开反馈入口", "Simplified feedback success should not duplicate the opened destination")
    expect(QuotaCopy(locale: .en).codexFeedbackHint.contains("Codex"), "English Codex feedback hint should name Codex")
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

final class SlowNotificationCodexTransport: CodexRPCTransport {
    private var responses: [[String: Any]]

    init(notificationCount: Int) {
        responses = [["jsonrpc": "2.0", "id": 1, "result": ["capabilities": [:]]]]
        responses.append(contentsOf: (0..<notificationCount).map { index in
            ["jsonrpc": "2.0", "method": "window/logMessage", "params": ["index": index]]
        })
        responses.append(["jsonrpc": "2.0", "id": 2, "result": ["rateLimits": [:]]])
    }

    func send(_ payload: [String: Any]) throws {}

    func readMessage(timeoutSeconds: TimeInterval) throws -> [String: Any] {
        Thread.sleep(forTimeInterval: 0.01)
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

func testCodexAppServerClientHandlesNotificationBurst() {
    var responses = (0..<75).map { index in
        ["jsonrpc": "2.0", "method": "window/logMessage", "params": ["index": index]] as [String: Any]
    }
    responses.append(["jsonrpc": "2.0", "id": 1, "result": ["capabilities": [:]]])
    responses.append(contentsOf: (0..<75).map { index in
        ["jsonrpc": "2.0", "method": "account/rateLimits/changed", "params": ["index": index]] as [String: Any]
    })
    responses.append([
        "jsonrpc": "2.0",
        "id": 2,
        "result": ["rateLimits": [
            "primary": ["usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1_788_271_414]
        ]]
    ])

    let snapshot = CodexAppServerClient.fetchSnapshot(
        transport: FakeCodexTransport(responses: responses),
        fetchedAt: Date(timeIntervalSince1970: 1_788_270_000),
        timeoutSeconds: 1
    )

    expect(snapshot.sourceStatus == .ok, "a burst of more than 50 notifications should not cause a false refresh failure")
    expect(snapshot.shortWindow?.usedPercent == 12, "notification burst should still reach the requested response")
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

func testCodexAppServerClientHandlesQueuedNotifications() throws {
    let executableURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("quota-capsule-fake-codex-\(UUID().uuidString)")
    let script = #"""
#!/bin/sh
IFS= read -r initialize
printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"capabilities":{}}}'
printf '%s\n' '{"jsonrpc":"2.0","method":"window/logMessage","params":{"message":"ready"}}'
IFS= read -r initialized
IFS= read -r rate_limits
printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"rateLimits":{"primary":{"usedPercent":62,"windowDurationMins":300,"resetsAt":1788271414},"secondary":{"usedPercent":24,"windowDurationMins":10080,"resetsAt":1788299735}}}}'
"""#
    try script.write(to: executableURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
    defer { try? FileManager.default.removeItem(at: executableURL) }

    let snapshot = CodexAppServerClient.fetchCurrent(
        codexPath: executableURL.path,
        timeoutSeconds: 2
    )

    expect(snapshot.sourceStatus == .ok, "app-server should ignore queued notifications and read the following response")
    expect(snapshot.shortWindow?.usedPercent == 62, "queued notification test should parse short window")
}

func testCodexAppServerClientReportsEarlyProcessExit() throws {
    let executableURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("quota-capsule-exiting-codex-\(UUID().uuidString)")
    let script = "#!/bin/sh\necho 'Bearer top-secret https://example.test/path?token=secret /Users/private/file' >&2\nexit 42\n"
    try script.write(to: executableURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
    defer { try? FileManager.default.removeItem(at: executableURL) }

    let startedAt = Date()
    let snapshot = CodexAppServerClient.fetchCurrent(codexPath: executableURL.path, timeoutSeconds: 2)

    expect(Date().timeIntervalSince(startedAt) < 1, "an exited child should wake the reader immediately")
    expect(snapshot.sourceStatus == .error, "an exited child should return an error snapshot")
    expect(snapshot.errorMessage?.contains("42") == true, "process exit diagnostics should preserve the exit status")
    expect(snapshot.errorMessage?.contains("top-secret") == false, "process diagnostics must redact bearer tokens")
    expect(snapshot.errorMessage?.contains("https://") == false, "process diagnostics must redact URLs")
    expect(snapshot.errorMessage?.contains("/Users/private") == false, "process diagnostics must redact home paths")
}

func testCodexAppServerClientUsesOneOverallDeadline() {
    let transport = SlowNotificationCodexTransport(notificationCount: 20)
    let startedAt = Date()
    let snapshot = CodexAppServerClient.fetchSnapshot(
        transport: transport,
        fetchedAt: startedAt,
        timeoutSeconds: 0.05
    )
    let elapsed = Date().timeIntervalSince(startedAt)

    expect(snapshot.sourceStatus == .error, "notifications must not extend the request beyond its deadline")
    expect(elapsed < 0.15, "the deadline should be total, not renewed for every notification")
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

func testCodexRateLimitParserRejectsUnsafeNumbers() {
    let fetchedAt = Date(timeIntervalSince1970: 1_788_270_000)
    let invalidWindows: [[String: Any]] = [
        ["usedPercent": -1, "windowDurationMins": 300, "resetsAt": 1_788_299_735],
        ["usedPercent": 101, "windowDurationMins": 300, "resetsAt": 1_788_299_735],
        ["usedPercent": 1, "windowDurationMins": 0, "resetsAt": 1_788_299_735],
        ["usedPercent": 1, "windowDurationMins": 1e300, "resetsAt": 1_788_299_735],
        ["usedPercent": 1, "windowDurationMins": 300, "resetsAt": Double.infinity]
    ]

    for window in invalidWindows {
        let snapshot = CodexRateLimitParser.parse(
            result: ["rateLimits": ["primary": window]],
            fetchedAt: fetchedAt
        )
        expect(snapshot.sourceStatus == .error, "unsafe numeric input must be rejected without trapping")
    }
}

func testCodexRateLimitParserPreservesFractionalUsage() {
    let snapshot = CodexRateLimitParser.parse(
        result: [
            "rateLimits": [
                "primary": ["usedPercent": 0.9, "windowDurationMins": 300, "resetsAt": 1_788_299_735]
            ]
        ],
        fetchedAt: Date(timeIntervalSince1970: 1_788_270_000)
    )

    expect(snapshot.shortWindow?.usedPercent == 0.9, "fractional usage must remain available to prediction math")
    expect(snapshot.shortWindow?.remainingPercent == 99.1, "fractional remaining quota must not be rounded early")
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

func testQuotaRefreshReducerMarksLastSuccessStaleAfterFailure() {
    let lastSuccessAt = Date(timeIntervalSince1970: 1_788_270_000)
    let now = lastSuccessAt.addingTimeInterval(60 * 60)
    let currentSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: lastSuccessAt,
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 20,
            remainingPercent: 80,
            resetsAt: lastSuccessAt.addingTimeInterval(120 * 60)
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

    expect(reduction.snapshot.sourceStatus == .stale, "refresh failure should explicitly mark cached data stale")
    expect(reduction.snapshot.shortWindow == currentSnapshot.shortWindow, "stale state should keep the last successful values for reference")
    expect(reduction.prediction.level == .unknown, "stale data must not remain green safe")
    expect(reduction.prediction.elapsedPercent == 60, "stale metrics should freeze at the successful fetch time instead of advancing to 80 percent")
    expect(reduction.latestAttemptSnapshot == failedSnapshot, "history should receive the failed attempt rather than another fake success")
    expect(reduction.lastRefreshText == "11:59:00", "refresh failure should preserve last success time")
    expect(reduction.lastAttemptText == "12:00:00", "refresh failure should update last attempt time")
    expect(reduction.lastErrorText?.contains("读取超时") == true, "refresh failure should keep readable error")
    expect(reduction.lastErrorText?.contains("\n") == false, "refresh failure error should be compressed to one line")
}

func testQuotaRefreshReducerDoesNotOverwriteAnActiveWindowWithWeeklyOnlyData() {
    let lastSuccessAt = Date(timeIntervalSince1970: 1_788_270_000)
    let now = lastSuccessAt.addingTimeInterval(60)
    let currentSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: lastSuccessAt,
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 20,
            remainingPercent: 80,
            resetsAt: lastSuccessAt.addingTimeInterval(120 * 60)
        ),
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 5,
            remainingPercent: 95,
            resetsAt: lastSuccessAt.addingTimeInterval(5_000 * 60)
        ),
        errorMessage: nil
    )
    let partialSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 10,
            remainingPercent: 90,
            resetsAt: lastSuccessAt.addingTimeInterval(5_000 * 60)
        ),
        errorMessage: nil
    )

    let reduction = QuotaRefreshReducer.reduce(
        currentSnapshot: currentSnapshot,
        currentLastRefreshText: "11:59:00",
        newSnapshot: partialSnapshot,
        now: now,
        attemptText: "12:00:00"
    )

    expect(reduction.snapshot.sourceStatus == .stale, "partial payload should make cached complete data stale")
    expect(reduction.snapshot.shortWindow == currentSnapshot.shortWindow, "partial payload must not erase the last valid 5-hour window")
    expect(reduction.snapshot.weeklyWindow == currentSnapshot.weeklyWindow, "one fetchedAt cannot safely mix fresh weekly and stale short windows")
    expect(reduction.latestAttemptSnapshot.sourceStatus == .error, "history should retain an active-window omission as a failed attempt")
    expect(reduction.latestAttemptSnapshot.weeklyWindow == partialSnapshot.weeklyWindow, "failed attempt should retain current weekly diagnostics")
    expect(reduction.prediction.level == .unknown, "cached data after a partial payload must not remain green safe")
}

func testQuotaRefreshReducerAcceptsWeeklyOnlyDataAfterTheShortWindowExpires() {
    let previousFetch = Date(timeIntervalSince1970: 1_788_270_000)
    let now = previousFetch.addingTimeInterval(180 * 60)
    let currentSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .stale,
        fetchedAt: previousFetch,
        shortWindow: QuotaWindow(
            label: "5h",
            windowMinutes: 300,
            usedPercent: 7,
            remainingPercent: 93,
            resetsAt: previousFetch.addingTimeInterval(120 * 60)
        ),
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 11,
            remainingPercent: 89,
            resetsAt: previousFetch.addingTimeInterval(5_000 * 60)
        ),
        errorMessage: "missing short window"
    )
    let weeklyOnlySnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .ok,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: QuotaWindow(
            label: "weekly",
            windowMinutes: 10_080,
            usedPercent: 0,
            remainingPercent: 100,
            resetsAt: now.addingTimeInterval(10_000 * 60)
        ),
        errorMessage: nil
    )

    let reduction = QuotaRefreshReducer.reduce(
        currentSnapshot: currentSnapshot,
        currentLastRefreshText: "02:22:20",
        newSnapshot: weeklyOnlySnapshot,
        now: now,
        attemptText: "08:22:20"
    )

    expect(reduction.snapshot == weeklyOnlySnapshot, "expired short data should be replaced by the current idle snapshot")
    expect(reduction.snapshot.sourceStatus == .ok, "waiting for a new short window is a live source state")
    expect(reduction.snapshot.weeklyWindow?.remainingPercent == 100, "idle state should display the latest weekly quota")
    expect(reduction.lastRefreshText == "08:22:20", "accepted idle data should update the last success time")
    expect(reduction.lastErrorText == nil, "accepted idle data should clear the old partial-response error")
    expect(reduction.prediction.headline.contains("等待新的 5 小时窗口"), "expired short window should transition to explicit waiting copy")
}

func testQuotaRefreshReducerSanitizesNetworkErrors() {
    let cleaned = QuotaRefreshReducer.cleanError(
        "failed to fetch codex rate limits: error sending request for url (https://chatgpt.com/backend-api/wham/usage?token=secret)",
        locale: .zhHans
    )

    expect(cleaned.contains("连接失败"), "network failures should use a readable localized classification")
    expect(!cleaned.contains("https://"), "network failures should not expose internal URLs")
    expect(!cleaned.contains("secret"), "network failures should not expose query values")
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

func testCodexAppServerClientRetriesOnlyTransientFailures() {
    let now = Date(timeIntervalSince1970: 1_788_270_000)
    let timeoutSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: nil,
        errorMessage: "codex app-server 读取超时。"
    )
    let sourceSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: nil,
        errorMessage: "codex app-server did not return a response for id=2."
    )
    let authSnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: nil,
        errorMessage: "not signed in"
    )
    let missingCLISnapshot = AgentQuotaSnapshot(
        provider: "codex",
        sourceStatus: .error,
        fetchedAt: now,
        shortWindow: nil,
        weeklyWindow: nil,
        errorMessage: "找不到 codex 命令。"
    )

    expect(CodexAppServerClient.shouldRetry(timeoutSnapshot), "timeout should be retried")
    expect(CodexAppServerClient.shouldRetry(sourceSnapshot), "transient source errors should be retried")
    expect(!CodexAppServerClient.shouldRetry(authSnapshot), "auth errors should not be retried")
    expect(!CodexAppServerClient.shouldRetry(missingCLISnapshot), "missing CLI should not be retried")
}

do {
    try testParsesCodexRateLimitsByDuration()
    testTreatsWeeklyOnlyRateLimitsAsWaitingForTheNextShortWindow()
    testRetryKeepsTheMostCompleteSnapshotAcrossAttempts()
    testPredictsBurnRateRunway()
    testFractionalUsageStaysConsistentInDisplayMath()
    testPredictsBelowReportingPrecisionConservatively()
    testPredictsBelowReportingPrecisionAsUnknownImmediatelyAfterReset()
    testWindowStartBoundaryIsWarmupNotClockError()
    testPredictorRejectsInvalidWindowWithoutTrapping()
    testPredictsExhaustedShortWindowAsDanger()
    testPredictsExhaustedWeeklyWindowAsDanger()
    testPredictsMissingShortWindowAsUnknownWhenWeeklyIsNotExhausted()
    testWeeklyPredictionUsesWeeklyWindowInputsOnly()
    testWeeklyPredictionWaitsForEnoughEarlyWindowSignal()
    testWeeklyPredictionDoesNotEstimateExactRunOutAtFivePercentEarlyWindow()
    testWeeklyPredictionFlagsFastEarlyBurnWithoutExactRunOutTime()
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
    testCodexAppServerClientHandlesNotificationBurst()
    testCodexAppServerClientReturnsRpcErrors()
    testCodexAppServerClientReturnsTransportErrors()
    try testCodexAppServerClientHandlesQueuedNotifications()
    try testCodexAppServerClientReportsEarlyProcessExit()
    testCodexAppServerClientUsesOneOverallDeadline()
    testCodexRateLimitParserRejectsMalformedWindows()
    testCodexRateLimitParserRejectsUnsafeNumbers()
    testCodexRateLimitParserPreservesFractionalUsage()
    try testCodexExecutableResolverFindsUserLocalBin()
    testCodexExecutableResolverReportsCheckedPaths()
    testQuotaRefreshReducerUpdatesOnSuccessfulRefresh()
    testQuotaRefreshReducerMarksLastSuccessStaleAfterFailure()
    testQuotaRefreshReducerDoesNotOverwriteAnActiveWindowWithWeeklyOnlyData()
    testQuotaRefreshReducerAcceptsWeeklyOnlyDataAfterTheShortWindowExpires()
    testQuotaRefreshReducerSanitizesNetworkErrors()
    testQuotaRefreshReducerUsesErrorWhenNoSuccessExists()
    testCodexAppServerClientDefaultTimeoutIsProductionTolerant()
    testCodexAppServerClientRetriesOnlyTransientFailures()
    print("QuotaCapsuleCoreSpec passed")
} catch {
    fputs("Spec failed with error: \(error)\n", stderr)
    exit(1)
}
