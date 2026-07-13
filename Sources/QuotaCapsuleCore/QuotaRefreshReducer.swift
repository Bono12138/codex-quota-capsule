import Foundation

public struct QuotaRefreshReduction: Equatable, Sendable {
    public let snapshot: AgentQuotaSnapshot
    public let lastRefreshText: String
    public let lastAttemptText: String
    public let lastErrorText: String?
    public let latestAttemptSnapshot: AgentQuotaSnapshot
}

public struct WeeklyForecastRefreshReduction: Equatable, Sendable {
    public let forecast: WeeklyRunwayForecast
    public let shouldAdoptLiveSnapshot: Bool

    public init(forecast: WeeklyRunwayForecast, shouldAdoptLiveSnapshot: Bool) {
        self.forecast = forecast
        self.shouldAdoptLiveSnapshot = shouldAdoptLiveSnapshot
    }
}

public enum QuotaRefreshReducer {
    public static func reduceForecast(
        currentForecast: WeeklyRunwayForecast,
        newSnapshot: AgentQuotaSnapshot,
        weeklyReadings: [WeeklyQuotaReading],
        now: Date,
        locale: QuotaLocale = .zhHans
    ) -> WeeklyRunwayForecast {
        reduceForecastResult(
            currentForecast: currentForecast,
            newSnapshot: newSnapshot,
            weeklyReadings: weeklyReadings,
            now: now,
            locale: locale
        ).forecast
    }

    public static func reduceForecastResult(
        currentForecast: WeeklyRunwayForecast,
        newSnapshot: AgentQuotaSnapshot,
        weeklyReadings: [WeeklyQuotaReading],
        now: Date,
        locale: QuotaLocale = .zhHans
    ) -> WeeklyForecastRefreshReduction {
        guard newSnapshot.sourceStatus == .ok, newSnapshot.weeklyWindow != nil else {
            return WeeklyForecastRefreshReduction(
                forecast: currentForecast,
                shouldAdoptLiveSnapshot: false
            )
        }
        let quality = WeeklyQualityEngine.analyze(weeklyReadings, now: now)
        guard quality.state != .calibrating else {
            return WeeklyForecastRefreshReduction(
                forecast: currentForecast,
                shouldAdoptLiveSnapshot: false
            )
        }
        return WeeklyForecastRefreshReduction(
            forecast: WeeklyRunwayPredictor.predict(
                snapshot: newSnapshot,
                quality: quality,
                now: now,
                locale: locale
            ),
            shouldAdoptLiveSnapshot: true
        )
    }

    public static func reduce(
        currentSnapshot: AgentQuotaSnapshot,
        currentLastRefreshText: String,
        newSnapshot: AgentQuotaSnapshot,
        now: Date,
        attemptText: String,
        locale: QuotaLocale = .zhHans
    ) -> QuotaRefreshReduction {
        if newSnapshot.sourceStatus == .ok, newSnapshot.weeklyWindow != nil {
            return QuotaRefreshReduction(
                snapshot: newSnapshot,
                lastRefreshText: attemptText,
                lastAttemptText: attemptText,
                lastErrorText: nil,
                latestAttemptSnapshot: newSnapshot
            )
        }

        let cleanedError = cleanError(newSnapshot.errorMessage, locale: locale)
        if (currentSnapshot.sourceStatus == .ok || currentSnapshot.sourceStatus == .stale),
           currentSnapshot.weeklyWindow != nil {
            let stale = AgentQuotaSnapshot(
                provider: currentSnapshot.provider,
                sourceStatus: .stale,
                fetchedAt: currentSnapshot.fetchedAt,
                weeklyWindow: currentSnapshot.weeklyWindow,
                errorMessage: cleanedError
            )
            return QuotaRefreshReduction(
                snapshot: stale,
                lastRefreshText: currentLastRefreshText,
                lastAttemptText: attemptText,
                lastErrorText: cleanedError,
                latestAttemptSnapshot: newSnapshot
            )
        }

        let failure = AgentQuotaSnapshot(
            provider: newSnapshot.provider,
            sourceStatus: .error,
            fetchedAt: newSnapshot.fetchedAt,
            weeklyWindow: nil,
            errorMessage: cleanedError
        )
        return QuotaRefreshReduction(
            snapshot: failure,
            lastRefreshText: currentLastRefreshText,
            lastAttemptText: attemptText,
            lastErrorText: cleanedError,
            latestAttemptSnapshot: newSnapshot
        )
    }

    public static func cleanError(_ message: String?, locale: QuotaLocale = .zhHans) -> String {
        guard let message, !message.isEmpty else {
            return QuotaCopy(locale: locale).unknownError
        }
        let normalized = message.lowercased()
        if normalized.contains("error sending request for url")
            || normalized.contains("failed to fetch codex rate limits") {
            return switch locale {
            case .zhHans: "Codex 额度服务暂时连接失败，应用会自动重试。"
            case .zhHant: "Codex 額度服務暫時連線失敗，App 會自動重試。"
            case .en: "Could not connect to the Codex quota service. The app will retry automatically."
            }
        }
        let firstLine = message
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\\n"#, with: " ")
            .replacingOccurrences(of: #"(?i)Bearer\s+[^\s]+"#, with: "Bearer [redacted]", options: .regularExpression)
            .replacingOccurrences(of: #"https?://[^\s)]+"#, with: "[remote service]", options: .regularExpression)
            .replacingOccurrences(of: #"/Users/[^/\s]+"#, with: "/Users/[redacted]", options: .regularExpression)
        return firstLine.count <= 320 ? firstLine : "\(firstLine.prefix(320))..."
    }
}
