import Foundation

public enum CodexRateLimitParser {
    public static func parse(resultData: Data, fetchedAt: Date) throws -> AgentQuotaSnapshot {
        let root = try JSONSerialization.jsonObject(with: resultData)
        return parse(result: root, fetchedAt: fetchedAt)
    }

    public static func parse(result: Any, fetchedAt: Date) -> AgentQuotaSnapshot {
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
                errorMessage: "codex app-server rateLimits did not include any usable windows."
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
              let resetsAtSeconds = readNumber(window["resetsAt"]) else {
            return nil
        }

        let used = clampPercent(Int(usedPercent.rounded()))
        let minutes = Int(windowMinutes.rounded())

        return QuotaWindow(
            label: minutes <= 360 ? "5h" : "weekly",
            windowMinutes: minutes,
            usedPercent: used,
            remainingPercent: clampPercent(100 - used),
            resetsAt: Date(timeIntervalSince1970: resetsAtSeconds)
        )
    }

    private static func readNumber(_ value: Any?) -> Double? {
        if let number = value as? Double {
            return number
        }
        if let number = value as? Int {
            return Double(number)
        }
        return nil
    }

    private static func clampPercent(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}

