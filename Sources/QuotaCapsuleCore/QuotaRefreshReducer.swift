import Foundation

public struct QuotaRefreshReduction: Equatable, Sendable {
    public let snapshot: AgentQuotaSnapshot
    public let prediction: CapsulePrediction
    public let displayModel: CapsuleDisplayModel
    public let lastRefreshText: String
    public let lastAttemptText: String
    public let lastErrorText: String?
    public let latestAttemptSnapshot: AgentQuotaSnapshot

    public init(
        snapshot: AgentQuotaSnapshot,
        prediction: CapsulePrediction,
        displayModel: CapsuleDisplayModel,
        lastRefreshText: String,
        lastAttemptText: String,
        lastErrorText: String?,
        latestAttemptSnapshot: AgentQuotaSnapshot
    ) {
        self.snapshot = snapshot
        self.prediction = prediction
        self.displayModel = displayModel
        self.lastRefreshText = lastRefreshText
        self.lastAttemptText = lastAttemptText
        self.lastErrorText = lastErrorText
        self.latestAttemptSnapshot = latestAttemptSnapshot
    }
}

public enum QuotaRefreshReducer {
    public static func reduce(
        currentSnapshot: AgentQuotaSnapshot,
        currentLastRefreshText: String,
        newSnapshot: AgentQuotaSnapshot,
        now: Date,
        attemptText: String,
        locale: QuotaLocale = .zhHans
    ) -> QuotaRefreshReduction {
        if newSnapshot.sourceStatus == .ok {
            return makeReduction(
                snapshot: newSnapshot,
                now: now,
                lastRefreshText: attemptText,
                lastAttemptText: attemptText,
                lastErrorText: nil,
                latestAttemptSnapshot: newSnapshot,
                locale: locale
            )
        }

        let cleanedError = cleanError(newSnapshot.errorMessage, locale: locale)

        if currentSnapshot.sourceStatus == .ok || currentSnapshot.sourceStatus == .stale,
           currentSnapshot.shortWindow != nil || currentSnapshot.weeklyWindow != nil {
            let staleSnapshot = AgentQuotaSnapshot(
                provider: currentSnapshot.provider,
                sourceStatus: .stale,
                fetchedAt: currentSnapshot.fetchedAt,
                shortWindow: currentSnapshot.shortWindow,
                weeklyWindow: currentSnapshot.weeklyWindow,
                errorMessage: cleanedError
            )
            return makeReduction(
                snapshot: staleSnapshot,
                now: now,
                lastRefreshText: currentLastRefreshText,
                lastAttemptText: attemptText,
                lastErrorText: cleanedError,
                latestAttemptSnapshot: newSnapshot,
                locale: locale
            )
        }

        let safeFailureSnapshot = AgentQuotaSnapshot(
            provider: newSnapshot.provider,
            sourceStatus: newSnapshot.sourceStatus,
            fetchedAt: newSnapshot.fetchedAt,
            shortWindow: newSnapshot.shortWindow,
            weeklyWindow: newSnapshot.weeklyWindow,
            errorMessage: cleanedError
        )
        return makeReduction(
            snapshot: safeFailureSnapshot,
            now: now,
            lastRefreshText: currentLastRefreshText,
            lastAttemptText: attemptText,
            lastErrorText: cleanedError,
            latestAttemptSnapshot: newSnapshot,
            locale: locale
        )
    }

    public static func cleanError(_ message: String?, locale: QuotaLocale = .zhHans) -> String {
        guard let message, !message.isEmpty else {
            return QuotaCopy(locale: locale).unknownError
        }

        let normalized = message.lowercased()
        if normalized.contains("error sending request for url")
            || normalized.contains("failed to fetch codex rate limits") {
            switch locale {
            case .zhHans: return "Codex 额度服务暂时连接失败，应用会自动重试。"
            case .zhHant: return "Codex 額度服務暫時連線失敗，App 會自動重試。"
            case .en: return "Could not connect to the Codex quota service. The app will retry automatically."
            }
        }

        let firstLine = message
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\\n"#, with: " ")
            .replacingOccurrences(of: #"(?i)Bearer\s+[^\s]+"#, with: "Bearer [redacted]", options: .regularExpression)
            .replacingOccurrences(of: #"https?://[^\s)]+"#, with: "[remote service]", options: .regularExpression)
            .replacingOccurrences(of: #"/Users/[^/\s]+"#, with: "/Users/[redacted]", options: .regularExpression)

        if firstLine.count <= 320 {
            return firstLine
        }
        return "\(firstLine.prefix(320))..."
    }

    private static func makeReduction(
        snapshot: AgentQuotaSnapshot,
        now: Date,
        lastRefreshText: String,
        lastAttemptText: String,
        lastErrorText: String?,
        latestAttemptSnapshot: AgentQuotaSnapshot,
        locale: QuotaLocale
    ) -> QuotaRefreshReduction {
        let prediction = QuotaPredictor.predict(snapshot: snapshot, now: now, locale: locale)
        let displayModel = CapsuleDisplayModel.make(prediction: prediction, locale: locale)

        return QuotaRefreshReduction(
            snapshot: snapshot,
            prediction: prediction,
            displayModel: displayModel,
            lastRefreshText: lastRefreshText,
            lastAttemptText: lastAttemptText,
            lastErrorText: lastErrorText,
            latestAttemptSnapshot: latestAttemptSnapshot
        )
    }
}
