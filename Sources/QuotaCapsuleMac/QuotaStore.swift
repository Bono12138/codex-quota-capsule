import Foundation
import SwiftUI
import QuotaCapsuleCore

enum OnboardingFocus {
    case capsule
    case detail
    case weekly
    case menu
    case feedback
}

@MainActor
final class QuotaStore: ObservableObject {
    @Published private(set) var snapshot: AgentQuotaSnapshot
    @Published private(set) var prediction: CapsulePrediction
    @Published private(set) var runwayForecast: WeeklyRunwayForecast
    @Published private(set) var displayModel: CapsuleDisplayModel
    @Published private(set) var copy: QuotaCopy
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var needsLanguageSelection: Bool
    @Published private(set) var analyticsConsent: AnalyticsConsent
    @Published private(set) var isPanelExpanded = false
    @Published private(set) var isCapsuleDocked = false
    @Published private(set) var capsuleWidth: CGFloat
    @Published private(set) var onboardingFocus: OnboardingFocus?
    @Published private(set) var lastRefreshText = ""
    @Published private(set) var lastAttemptText = ""
    @Published private(set) var lastErrorText: String?

    private var refreshTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var expandedStartedAt: Date?
    private var isFlushingAnalytics = false
    private var needsAnalyticsFlush = false
    private var analyticsUploadTask: Task<Void, Never>?
    private var analyticsUploadGeneration = 0
    private let configuration: AppConfiguration
    private let userDefaults: UserDefaults
    private let historyStore: QuotaHistoryStore
    private var locale: QuotaLocale
    private let launchedAt = Date()
    private let onboardingKey: String
    private let localeKey: String
    private let analyticsConsentKey: String
    private let capsuleWidthKey: String
    private let lastSessionDurationKey: String
    private let expandedCountKey: String
    private let feedbackNudgeShownKey: String
    private let minCapsuleWidth: CGFloat = 340
    private let maxCapsuleWidth: CGFloat = 560
    private let feedbackNudgeExpansionThreshold = 6

    init(configuration: AppConfiguration = .current(), userDefaults: UserDefaults = .standard) {
        self.configuration = configuration
        self.userDefaults = userDefaults
        historyStore = QuotaHistoryStore(configuration: configuration, userDefaults: userDefaults)
        onboardingKey = configuration.userDefaultsKey("hasCompletedOnboarding")
        localeKey = configuration.userDefaultsKey("selectedLocale")
        analyticsConsentKey = configuration.userDefaultsKey("analyticsConsent")
        capsuleWidthKey = configuration.userDefaultsKey("capsuleWidth")
        lastSessionDurationKey = configuration.userDefaultsKey("lastSessionDuration.seconds")
        expandedCountKey = configuration.userDefaultsKey("panelExpanded.count")
        feedbackNudgeShownKey = configuration.userDefaultsKey("feedbackNudge.shown")

        let storedLocale = userDefaults.string(forKey: localeKey).flatMap(QuotaLocale.init(rawValue:))
        let systemLocale = QuotaLocale.supported()
        locale = storedLocale ?? systemLocale ?? .en
        let initialCopy = QuotaCopy(locale: locale)
        copy = initialCopy
        needsLanguageSelection = storedLocale == nil
        hasCompletedOnboarding = userDefaults.bool(forKey: onboardingKey)
        analyticsConsent = userDefaults.string(forKey: analyticsConsentKey)
            .flatMap(AnalyticsConsent.init(rawValue:)) ?? .undecided
        let storedWidth = userDefaults.double(forKey: capsuleWidthKey)
        capsuleWidth = storedWidth > 0 ? min(max(CGFloat(storedWidth), minCapsuleWidth), maxCapsuleWidth) : 420
        let now = Date()
        let initial = AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .error,
            fetchedAt: now,
            shortWindow: nil,
            weeklyWindow: nil,
            errorMessage: initialCopy.initialLoadingError
        )
        let initialPrediction = QuotaPredictor.predict(snapshot: initial, now: now, locale: locale)
        snapshot = initial
        prediction = initialPrediction
        let initialForecast = WeeklyRunwayPredictor.predict(
            snapshot: initial,
            quality: WeeklyQualityResult(state: .unavailable, observations: [], canonicalResetAt: nil, flags: []),
            now: now,
            locale: locale
        )
        runwayForecast = initialForecast
        displayModel = CapsuleDisplayModel.make(forecast: initialForecast, locale: locale)
        lastRefreshText = initialCopy.notRefreshed
        lastAttemptText = initialCopy.notAttempted

        recordEvent(name: "app_launched", surface: "app", requiresConsent: false)
        refresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await MainActor.run {
                    self?.refresh()
                }
            }
        }
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                await MainActor.run {
                    self?.recordHeartbeat()
                }
            }
        }
    }

    deinit {
        refreshTask?.cancel()
        heartbeatTask?.cancel()
        analyticsUploadTask?.cancel()
        Task { @MainActor [launchedAt, lastSessionDurationKey] in
            let duration = Date().timeIntervalSince(launchedAt)
            UserDefaults.standard.set(duration, forKey: lastSessionDurationKey)
        }
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        recordEvent(name: "quota_refresh_started", surface: "menu_bar", requiresConsent: false)
        let locale = self.locale
        let retryWeeklyOnly = snapshot.shortWindow.map { $0.resetsAt > Date() } ?? false
        Task.detached(priority: .utility) {
            let snapshot = await CodexAppServerClient.fetchCurrentWithRetry(
                locale: locale,
                retryWeeklyOnly: retryWeeklyOnly
            )
            let now = Date()

            await MainActor.run {
                self.applyRefreshResult(snapshot, now: now)
                self.isRefreshing = false
            }
        }
    }

    var weeklyText: String {
        guard let weeklyWindow = snapshot.weeklyWindow else {
            return copy.unknownValue
        }
        return Self.formatQuotaPercent(weeklyWindow.remainingPercent)
    }

    var weeklyProjectionText: String {
        displayModel.defaultText
    }

    var weeklyProjectionTone: CapsuleLevel {
        displayModel.tone
    }

    var resetText: String {
        guard let resetsAt = snapshot.weeklyWindow?.resetsAt else {
            return copy.unknownValue
        }
        return QuotaPredictor.formatTime(resetsAt, locale: locale)
    }

    var sourceText: String {
        if snapshot.sourceStatus == .ok {
            if let lastErrorText {
                return copy.sourceShowingLastSuccess(lastRefreshText: lastRefreshText, error: lastErrorText)
            }
            return copy.sourceSuccess(lastRefreshText)
        }
        if snapshot.sourceStatus == .stale {
            return copy.sourceShowingLastSuccess(
                lastRefreshText: lastRefreshText,
                error: lastErrorText ?? snapshot.errorMessage ?? copy.unknownError
            )
        }
        return copy.sourceUnavailable(lastErrorText ?? snapshot.errorMessage ?? copy.unknownError)
    }

    var sourceNameText: String {
        copy.sourceName
    }

    var sourceEndpointText: String {
        copy.sourceEndpoint
    }

    var sourceStatusText: String {
        if snapshot.sourceStatus == .ok {
            if lastErrorText != nil {
                return copy.sourceStatusShowingLastSuccess
            }
            return copy.sourceStatusLive
        }
        if snapshot.sourceStatus == .stale {
            return copy.sourceStatusShowingLastSuccess
        }
        return copy.sourceStatusFailed
    }

    var sourceNoteText: String {
        if snapshot.sourceStatus == .stale, let lastErrorText {
            return copy.sourceLatestFailure(lastErrorText)
        }
        if snapshot.sourceStatus == .ok, let lastErrorText {
            return copy.sourceLatestFailure(lastErrorText)
        }
        if snapshot.sourceStatus == .ok {
            return copy.sourceLastAttempt(lastAttemptText)
        }
        return lastErrorText ?? snapshot.errorMessage ?? copy.unknownError
    }

    var visibleStatusText: String {
        if isRefreshing && snapshot.sourceStatus != .ok {
            return copy.loadingStatus
        }
        return snapshot.sourceStatus == .stale ? copy.statusStale : displayModel.statusLabel
    }

    var visibleCompactText: String {
        if isRefreshing && snapshot.sourceStatus != .ok {
            return copy.loadingCompact
        }
        return displayModel.compactDetail
    }

    var visibleMenuBarText: String {
        if isRefreshing && snapshot.sourceStatus != .ok {
            return visibleStatusText
        }
        if let usedText = visibleCompactUsedBadgeText {
            return "\(visibleStatusText) \(usedText)"
        }
        return visibleStatusText
    }

    var compactPaceText: String {
        guard displayModel.metrics.count >= 2 else { return copy.unknownValue }
        return "\(displayModel.metrics[0].label) \(displayModel.metrics[0].value) · \(displayModel.metrics[1].label) \(displayModel.metrics[1].value)"
    }

    var compactElapsedPercent: Int? {
        displayModel.metrics.first?.numericValue
    }

    var compactUsedPercent: Int? {
        displayModel.metrics.dropFirst().first?.numericValue
    }

    var visibleCompactUsedBadgeText: String? {
        guard let compactUsedValueText else {
            return nil
        }
        return copy.compactUsedBadge(value: compactUsedValueText)
    }

    var compactUsedValueText: String? {
        displayModel.metrics.first { $0.label == copy.metricUsed }?.value
    }

    var compactProjectedText: String {
        displayModel.defaultText
    }

    var analyticsConsentText: String {
        switch analyticsConsent {
        case .undecided: copy.analyticsUndecidedText
        case .granted: copy.analyticsGrantedText
        case .denied: copy.analyticsDeniedText
        }
    }

    var historyDatabaseSizeText: String {
        copy.historyDatabaseSize(formatBytes(historyStore.databaseSizeBytes))
    }

    var githubIssuesURL: URL? {
        configuration.githubIssuesURL
    }

    var releaseChannel: ReleaseChannel {
        configuration.channel
    }

    var appDisplayName: String {
        configuration.displayName
    }

    func completeOnboarding() {
        userDefaults.set(true, forKey: onboardingKey)
        hasCompletedOnboarding = true
        onboardingFocus = nil
        recordEvent(name: "onboarding_completed", surface: "onboarding")
    }

    func skipOnboarding() {
        userDefaults.set(true, forKey: onboardingKey)
        hasCompletedOnboarding = true
        onboardingFocus = nil
        recordEvent(name: "onboarding_skipped", surface: "onboarding")
    }

    func selectLocale(_ nextLocale: QuotaLocale) {
        locale = nextLocale
        copy = QuotaCopy(locale: nextLocale)
        needsLanguageSelection = false
        userDefaults.set(nextLocale.rawValue, forKey: localeKey)
        recomputeDisplay(now: Date())
        recordEvent(name: "language_selected", surface: "onboarding", properties: ["language": nextLocale.analyticsCode])
    }

    func setAnalyticsConsent(_ consent: AnalyticsConsent) {
        analyticsConsent = consent
        userDefaults.set(consent.rawValue, forKey: analyticsConsentKey)
        if consent == .denied {
            analyticsUploadGeneration += 1
            analyticsUploadTask?.cancel()
            analyticsUploadTask = nil
            isFlushingAnalytics = false
            needsAnalyticsFlush = false
            historyStore.disablePendingProductImprovementUploads()
        }
        recordEvent(
            name: "analytics_consent_changed",
            surface: "onboarding",
            properties: ["consent": consent.rawValue]
        )
        flushAnalyticsUploads()
    }

    func setPanelExpanded(_ expanded: Bool, surface: String = "capsule") {
        guard expanded != isPanelExpanded else { return }
        if expanded {
            isCapsuleDocked = false
        }
        isPanelExpanded = expanded
        if expanded {
            expandedStartedAt = Date()
            recordEvent(name: "capsule_expanded", surface: surface)
            evaluateFeedbackNudge()
        } else {
            let duration = expandedStartedAt.map { Date().timeIntervalSince($0) }
            expandedStartedAt = nil
            recordEvent(name: "capsule_collapsed", surface: surface, durationSeconds: duration)
        }
    }

    func setCapsuleDocked(_ docked: Bool) {
        guard docked != isCapsuleDocked else { return }
        isCapsuleDocked = docked
        if docked, isPanelExpanded {
            setPanelExpanded(false)
        }
    }

    func setCapsuleWidth(_ width: CGFloat, commit: Bool = false) {
        let clamped = min(max(width, minCapsuleWidth), maxCapsuleWidth)
        guard abs(capsuleWidth - clamped) >= 0.5 || commit else { return }
        capsuleWidth = clamped
        if commit {
            userDefaults.set(Double(clamped), forKey: capsuleWidthKey)
            recordEvent(
                name: "capsule_resized",
                surface: "capsule",
                widthBucket: widthBucket(clamped)
            )
        }
    }

    func recordFeedbackClick(_ target: String) {
        recordEvent(name: "feedback_clicked", surface: "feedback", feedbackTarget: target, requiresConsent: true)
    }

    func recordFeedbackWindowOpened() {
        recordEvent(name: "feedback_window_opened", surface: "feedback", requiresConsent: true)
    }

    func recordFeedbackNudgeDecision(_ decision: String) {
        recordEvent(
            name: "feedback_nudge_decision",
            surface: "feedback",
            requiresConsent: true,
            properties: ["decision": decision]
        )
    }

    func recordCapsuleVisibility(visible: Bool, durationSeconds: Double? = nil) {
        recordEvent(
            name: visible ? "capsule_visible" : "capsule_hidden",
            surface: "capsule",
            durationSeconds: durationSeconds,
            properties: [
                "panel_state": isPanelExpanded ? "expanded" : "collapsed",
                "capsule_state": isCapsuleDocked ? "docked" : "floating",
                "width_bucket": widthBucket(capsuleWidth)
            ]
        )
    }

    func recordMenuOpened() {
        recordEvent(name: "menu_opened", surface: "menu_bar")
    }

    func recordSettingsOpened(surface: String) {
        recordEvent(name: "settings_opened", surface: surface)
    }

    func recordCapsuleEdgeHidden(_ edge: String) {
        recordEvent(name: "capsule_edge_hidden", surface: "capsule", properties: ["edge": edge])
    }

    func recordCapsuleEdgeRevealed(_ edge: String) {
        recordEvent(name: "capsule_edge_revealed", surface: "capsule", properties: ["edge": edge])
    }

    func recordOnboardingStarted() {
        recordEvent(name: "onboarding_started", surface: "onboarding", requiresConsent: true)
    }

    func recordOnboardingStep(_ step: String) {
        recordEvent(name: "onboarding_step_viewed", surface: "onboarding", requiresConsent: true, properties: ["step": step])
    }

    func setOnboardingFocus(_ focus: OnboardingFocus?) {
        onboardingFocus = focus
    }

    func clearLocalHistory() {
        historyStore.clearAll()
    }

    func trackAppQuit() {
        recordEvent(
            name: "app_quit",
            surface: "app",
            durationSeconds: Date().timeIntervalSince(launchedAt),
            requiresConsent: true
        )
    }

    private func applyRefreshResult(_ newSnapshot: AgentQuotaSnapshot, now: Date) {
        let attemptText = QuotaStore.timeFormatter(for: locale).string(from: now)
        let reduction = QuotaRefreshReducer.reduce(
            currentSnapshot: snapshot,
            currentLastRefreshText: lastRefreshText,
            newSnapshot: newSnapshot,
            now: now,
            attemptText: attemptText,
            locale: locale
        )

        snapshot = reduction.snapshot
        prediction = reduction.prediction
        displayModel = reduction.displayModel
        lastRefreshText = reduction.lastRefreshText
        lastAttemptText = reduction.lastAttemptText
        lastErrorText = reduction.lastErrorText
        let attemptSnapshot = reduction.latestAttemptSnapshot
        if attemptSnapshot.sourceStatus == .ok {
            historyStore.recordWeeklySnapshot(attemptSnapshot)
            let readings = historyStore.recentWeeklyReadings()
            runwayForecast = QuotaRefreshReducer.reduceForecast(
                currentForecast: runwayForecast,
                newSnapshot: reduction.snapshot,
                weeklyReadings: readings,
                now: now,
                locale: locale
            )
            recordQuotaStateSample()
        }
        displayModel = CapsuleDisplayModel.make(forecast: runwayForecast, locale: locale)
        recordEvent(
            name: attemptSnapshot.sourceStatus == .ok ? "quota_refresh_succeeded" : "quota_refresh_failed",
            surface: "source",
            sourceStatus: attemptSnapshot.sourceStatus,
            errorType: attemptSnapshot.sourceStatus == .ok ? nil : "source_error",
            requiresConsent: false
        )
    }

    private func recordHeartbeat() {
        recordEvent(
            name: "app_heartbeat",
            surface: "app",
            durationSeconds: Date().timeIntervalSince(launchedAt),
            requiresConsent: true,
            properties: [
                "panel_state": isPanelExpanded ? "expanded" : "collapsed",
                "capsule_state": isCapsuleDocked ? "docked" : "floating",
                "width_bucket": widthBucket(capsuleWidth)
            ]
        )
    }

    private func evaluateFeedbackNudge() {
        guard hasCompletedOnboarding,
              !userDefaults.bool(forKey: feedbackNudgeShownKey) else {
            return
        }

        let expandedCount = userDefaults.integer(forKey: expandedCountKey) + 1
        userDefaults.set(expandedCount, forKey: expandedCountKey)

        guard expandedCount >= feedbackNudgeExpansionThreshold else {
            return
        }

        userDefaults.set(true, forKey: feedbackNudgeShownKey)
        recordEvent(
            name: "feedback_nudge_shown",
            surface: "feedback",
            requiresConsent: true,
            properties: ["trigger": "expanded_count"]
        )
        NotificationCenter.default.post(name: .quotaCapsuleRequestFeedbackNudge, object: nil)
    }

    private func recordQuotaStateSample() {
        guard snapshot.sourceStatus == .ok else { return }

        var properties: [String: String] = [
            "panel_state": isPanelExpanded ? "expanded" : "collapsed",
            "capsule_state": isCapsuleDocked ? "docked" : "floating",
            "width_bucket": widthBucket(capsuleWidth)
        ]

        if let shortWindow = snapshot.shortWindow {
            properties["short_window_minutes"] = "\(shortWindow.windowMinutes)"
            properties["short_used_percent"] = "\(shortWindow.usedPercent)"
            properties["short_remaining_percent"] = "\(shortWindow.remainingPercent)"
        }
        if let elapsed = prediction.elapsedPercent {
            properties["short_elapsed_percent"] = "\(elapsed)"
        }
        if let projected = prediction.projectedRemainingAtReset {
            properties["projected_remaining_at_reset_percent"] = "\(projected)"
        }

        if let weeklyWindow = snapshot.weeklyWindow {
            let weeklyPrediction = QuotaPredictor.predictWeekly(window: weeklyWindow, now: snapshot.fetchedAt, locale: locale)
            properties["weekly_window_minutes"] = "\(weeklyWindow.windowMinutes)"
            properties["weekly_used_percent"] = "\(weeklyWindow.usedPercent)"
            properties["weekly_remaining_percent"] = "\(weeklyWindow.remainingPercent)"
            if let weeklyElapsed = weeklyPrediction.elapsedPercent {
                properties["weekly_elapsed_percent"] = "\(weeklyElapsed)"
            }
            if let weeklyProjected = weeklyPrediction.projectedRemainingAtReset {
                properties["weekly_projected_remaining_percent"] = "\(weeklyProjected)"
            }
        }

        recordEvent(
            name: "quota_state_sampled",
            surface: "source",
            status: prediction.level,
            sourceStatus: snapshot.sourceStatus,
            requiresConsent: true,
            properties: properties
        )
    }

    private func recomputeDisplay(now: Date) {
        prediction = QuotaPredictor.predict(snapshot: snapshot, now: now, locale: locale)
        displayModel = CapsuleDisplayModel.make(forecast: runwayForecast, locale: locale)
        lastRefreshText = lastRefreshText == QuotaCopy(locale: .zhHans).notRefreshed ? copy.notRefreshed : lastRefreshText
        lastAttemptText = lastAttemptText == QuotaCopy(locale: .zhHans).notAttempted ? copy.notAttempted : lastAttemptText
    }

    private func recordEvent(
        name: String,
        surface: String? = nil,
        status: CapsuleLevel? = nil,
        sourceStatus: SourceStatus? = nil,
        errorType: String? = nil,
        durationSeconds: Double? = nil,
        count: Int? = nil,
        widthBucket: String? = nil,
        feedbackTarget: String? = nil,
        requiresConsent: Bool = true,
        properties: [String: String] = [:]
    ) {
        var eventProperties = properties
        eventProperties["collection_tier"] = requiresConsent ? "product_improvement" : "essential_diagnostics"
        eventProperties["release_channel"] = configuration.channel.rawValue
        let event = ProductAnalyticsEvent(
            name: name,
            surface: surface,
            status: status ?? prediction.level,
            sourceStatus: sourceStatus ?? snapshot.sourceStatus,
            errorType: errorType,
            durationSeconds: durationSeconds,
            count: count,
            widthBucket: widthBucket,
            language: locale,
            feedbackTarget: feedbackTarget,
            properties: eventProperties
        )
        let uploadAllowed = requiresConsent ? analyticsConsent == .granted : true
        _ = historyStore.recordEvent(event, consent: analyticsConsent, uploadAllowed: uploadAllowed)
        flushAnalyticsUploads()
    }

    private func flushAnalyticsUploads() {
        guard ProductAnalyticsUploader.endpointURL(configuration: configuration) != nil else {
            return
        }

        if isFlushingAnalytics {
            needsAnalyticsFlush = true
            return
        }

        let uploads = historyStore.pendingUploads(limit: 10)
        guard !uploads.isEmpty else { return }

        isFlushingAnalytics = true
        analyticsUploadGeneration += 1
        let uploadGeneration = analyticsUploadGeneration
        analyticsUploadTask = Task { @MainActor in
            for upload in uploads {
                guard !Task.isCancelled, uploadGeneration == analyticsUploadGeneration else { break }
                if upload.isProductImprovement, analyticsConsent != .granted {
                    historyStore.disableUpload(id: upload.id)
                    continue
                }
                let sent = await ProductAnalyticsUploader.upload(payload: upload.payload, configuration: configuration)
                guard !Task.isCancelled, uploadGeneration == analyticsUploadGeneration else { break }
                if sent {
                    historyStore.markUploadSent(id: upload.id)
                } else {
                    historyStore.markUploadFailed(id: upload.id)
                }
            }
            guard uploadGeneration == analyticsUploadGeneration else { return }
            isFlushingAnalytics = false
            analyticsUploadTask = nil
            if needsAnalyticsFlush {
                needsAnalyticsFlush = false
                flushAnalyticsUploads()
            }
        }
    }

    static func timeFormatter(for locale: QuotaLocale) -> DateFormatter {
        let formatter = DateFormatter()
        switch locale {
        case .zhHans:
            formatter.locale = Locale(identifier: "zh_CN")
        case .zhHant:
            formatter.locale = Locale(identifier: "zh_TW")
        case .en:
            formatter.locale = Locale(identifier: "en_US_POSIX")
        }
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }

    private static func formatQuotaPercent(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))%"
        }
        return String(format: "%.1f%%", value)
    }

}

private func widthBucket(_ width: CGFloat) -> String {
    switch width {
    case ..<380:
        return "small"
    case ..<480:
        return "medium"
    default:
        return "large"
    }
}

private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}
