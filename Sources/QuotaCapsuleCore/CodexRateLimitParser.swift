import Foundation

public enum CodexRateLimitParser {
    public static func parse(resultData: Data, fetchedAt: Date, locale: QuotaLocale = .zhHans) throws -> AgentQuotaSnapshot {
        let root = try JSONSerialization.jsonObject(with: resultData)
        return parse(result: root, fetchedAt: fetchedAt, locale: locale)
    }

    public static func parse(result: Any, fetchedAt: Date, locale: QuotaLocale = .zhHans) -> AgentQuotaSnapshot {
        let root = result as? [String: Any] ?? [:]
        let rateLimits = root["rateLimits"] as? [String: Any] ?? [:]
        let windows = ["primary", "secondary"].compactMap { key in
            parseWindow(rateLimits[key])
        }

        let latestPlausibleReset = fetchedAt.addingTimeInterval(8 * 24 * 60 * 60)
        let weeklyWindow = windows.first { window in
            abs(window.windowMinutes - 10_080) <= 60
                && window.resetsAt > fetchedAt
                && window.resetsAt <= latestPlausibleReset
        }

        guard let weeklyWindow else {
            return AgentQuotaSnapshot(
                provider: "codex",
                sourceStatus: .error,
                fetchedAt: fetchedAt,
                weeklyWindow: nil,
                errorMessage: missingUsableWindowsMessage(locale)
            )
        }

        return AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .ok,
            fetchedAt: fetchedAt,
            weeklyWindow: weeklyWindow,
            errorMessage: nil
        )
    }

    private static func parseWindow(_ value: Any?) -> QuotaWindow? {
        guard let window = value as? [String: Any],
              let usedPercent = readNumber(window["usedPercent"]),
              let windowMinutes = readNumber(window["windowDurationMins"]),
              let resetsAtSeconds = readNumber(window["resetsAt"]),
              usedPercent.isFinite,
              (0...100).contains(usedPercent),
              windowMinutes.isFinite,
              windowMinutes >= 1,
              windowMinutes <= 525_600,
              windowMinutes.rounded() == windowMinutes,
              resetsAtSeconds.isFinite,
              resetsAtSeconds >= 946_684_800,
              resetsAtSeconds <= 4_102_444_800 else {
            return nil
        }

        let minutes = Int(windowMinutes.rounded())

        return QuotaWindow(
            label: "weekly",
            windowMinutes: minutes,
            usedPercent: usedPercent,
            remainingPercent: 100 - usedPercent,
            resetsAt: Date(timeIntervalSince1970: resetsAtSeconds)
        )
    }

    private static func readNumber(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }
        return number.doubleValue
    }

    private static func missingUsableWindowsMessage(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "codex app-server rateLimits 没有包含可用额度窗口。"
        case .zhHant: "codex app-server rateLimits 沒有包含可用額度週期。"
        case .en: "codex app-server rateLimits did not include any usable windows."
        }
    }

}
