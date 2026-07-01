import Foundation

public struct QuotaRefreshReduction: Equatable, Sendable {
    public let snapshot: AgentQuotaSnapshot
    public let prediction: CapsulePrediction
    public let displayModel: CapsuleDisplayModel
    public let lastRefreshText: String
    public let lastAttemptText: String
    public let lastErrorText: String?

    public init(
        snapshot: AgentQuotaSnapshot,
        prediction: CapsulePrediction,
        displayModel: CapsuleDisplayModel,
        lastRefreshText: String,
        lastAttemptText: String,
        lastErrorText: String?
    ) {
        self.snapshot = snapshot
        self.prediction = prediction
        self.displayModel = displayModel
        self.lastRefreshText = lastRefreshText
        self.lastAttemptText = lastAttemptText
        self.lastErrorText = lastErrorText
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
                locale: locale
            )
        }

        let cleanedError = cleanError(newSnapshot.errorMessage, locale: locale)

        if currentSnapshot.sourceStatus == .ok {
            return makeReduction(
                snapshot: currentSnapshot,
                now: now,
                lastRefreshText: currentLastRefreshText,
                lastAttemptText: attemptText,
                lastErrorText: cleanedError,
                locale: locale
            )
        }

        return makeReduction(
            snapshot: newSnapshot,
            now: now,
            lastRefreshText: currentLastRefreshText,
            lastAttemptText: attemptText,
            lastErrorText: cleanedError,
            locale: locale
        )
    }

    public static func cleanError(_ message: String?, locale: QuotaLocale = .zhHans) -> String {
        guard let message, !message.isEmpty else {
            return QuotaCopy(locale: locale).unknownError
        }

        let firstLine = message
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\\n"#, with: " ")

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
            lastErrorText: lastErrorText
        )
    }
}
