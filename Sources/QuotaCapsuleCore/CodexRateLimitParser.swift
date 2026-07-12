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

        let shortWindow = windows.first { $0.windowMinutes <= 360 }
        let weeklyWindow = windows.first { $0.windowMinutes > 360 }

        guard shortWindow != nil || weeklyWindow != nil else {
            return AgentQuotaSnapshot(
                provider: "codex",
                sourceStatus: .error,
                fetchedAt: fetchedAt,
                shortWindow: nil,
                weeklyWindow: nil,
                errorMessage: missingUsableWindowsMessage(locale)
            )
        }

        return AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .ok,
            fetchedAt: fetchedAt,
            shortWindow: shortWindow,
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
            label: minutes <= 360 ? "5h" : "weekly",
            windowMinutes: minutes,
            usedPercent: usedPercent,
            remainingPercent: 100 - usedPercent,
            resetsAt: Date(timeIntervalSince1970: resetsAtSeconds)
        )
    }

    private static func readNumber(_ value: Any?) -> Double? {
        guard !(value is Bool) else {
            return nil
        }
        if let number = value as? Double {
            return number
        }
        if let number = value as? Int {
            return Double(number)
        }
        return nil
    }

    private static func missingUsableWindowsMessage(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "codex app-server rateLimits 没有包含可用额度窗口。"
        case .zhHant: "codex app-server rateLimits 沒有包含可用額度週期。"
        case .en: "codex app-server rateLimits did not include any usable windows."
        }
    }
}
