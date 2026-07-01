import Foundation
import SwiftUI
import QuotaCapsuleCore

@MainActor
final class QuotaStore: ObservableObject {
    @Published private(set) var snapshot: AgentQuotaSnapshot
    @Published private(set) var prediction: CapsulePrediction
    @Published private(set) var displayModel: CapsuleDisplayModel
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshText = ""
    @Published private(set) var lastAttemptText = ""
    @Published private(set) var lastErrorText: String?

    private var refreshTask: Task<Void, Never>?
    let copy: QuotaCopy
    private let locale: QuotaLocale

    init() {
        locale = QuotaLocale.current()
        copy = QuotaCopy(locale: locale)
        let now = Date()
        let initial = AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .error,
            fetchedAt: now,
            shortWindow: nil,
            weeklyWindow: nil,
            errorMessage: copy.initialLoadingError
        )
        let initialPrediction = QuotaPredictor.predict(snapshot: initial, now: now, locale: locale)
        snapshot = initial
        prediction = initialPrediction
        displayModel = CapsuleDisplayModel.make(prediction: initialPrediction, locale: locale)
        lastRefreshText = copy.notRefreshed
        lastAttemptText = copy.notAttempted

        refresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await MainActor.run {
                    self?.refresh()
                }
            }
        }
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        let locale = self.locale
        Task.detached(priority: .utility) {
            let snapshot = CodexAppServerClient.fetchCurrent(locale: locale)
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
        return "\(weeklyWindow.remainingPercent)%"
    }

    var resetText: String {
        guard let resetsAt = snapshot.shortWindow?.resetsAt else {
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
        return copy.sourceStatusFailed
    }

    var sourceNoteText: String {
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
        return displayModel.statusLabel
    }

    var visibleCompactText: String {
        if isRefreshing && snapshot.sourceStatus != .ok {
            return copy.loadingCompact
        }
        return displayModel.defaultText
    }

    private func applyRefreshResult(_ newSnapshot: AgentQuotaSnapshot, now: Date) {
        let attemptText = QuotaStore.timeFormatter.string(from: now)
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
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
