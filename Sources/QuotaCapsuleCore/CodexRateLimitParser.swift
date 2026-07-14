import CryptoKit
import Foundation

public enum CodexRateLimitParser {
    public static func parse(resultData: Data, fetchedAt: Date, locale: QuotaLocale = .zhHans) throws -> AgentQuotaSnapshot {
        let root = try JSONSerialization.jsonObject(with: resultData)
        return parse(result: root, fetchedAt: fetchedAt, locale: locale)
    }

    public static func parse(result: Any, fetchedAt: Date, locale: QuotaLocale = .zhHans) -> AgentQuotaSnapshot {
        let root = result as? [String: Any] ?? [:]
        let rateLimits = root["rateLimits"] as? [String: Any] ?? [:]
        let resetCreditBank = parseResetCreditBank(root["rateLimitResetCredits"], fetchedAt: fetchedAt)
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
                resetCreditBank: resetCreditBank,
                errorMessage: missingUsableWindowsMessage(locale)
            )
        }

        return AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .ok,
            fetchedAt: fetchedAt,
            weeklyWindow: weeklyWindow,
            resetCreditBank: resetCreditBank,
            errorMessage: nil
        )
    }

    private static func parseResetCreditBank(_ value: Any?, fetchedAt: Date) -> ResetCreditBankSummary? {
        guard let bank = value as? [String: Any],
              let availableCountValue = readNumber(bank["availableCount"]),
              availableCountValue.isFinite,
              availableCountValue.rounded() == availableCountValue,
              (0...1_000_000).contains(availableCountValue) else {
            return nil
        }
        let availableCount = Int(availableCountValue)
        let creditsValue = bank["credits"]
        if creditsValue == nil || creditsValue is NSNull {
            return ResetCreditBankSummary(
                availableCount: availableCount,
                credits: nil,
                detailState: .countOnly,
                fetchedAt: fetchedAt
            )
        }
        guard let rawCredits = creditsValue as? [Any] else {
            return ResetCreditBankSummary(
                availableCount: availableCount,
                credits: nil,
                detailState: .countOnly,
                fetchedAt: fetchedAt
            )
        }

        let credits = rawCredits.compactMap(parseResetCredit).sorted(by: resetCreditSort)
        let validatedAvailableCount = credits.lazy.filter { $0.status == .available }.count
        return ResetCreditBankSummary(
            availableCount: availableCount,
            credits: credits,
            detailState: validatedAvailableCount < availableCount ? .capped : .complete,
            fetchedAt: fetchedAt
        )
    }

    private static func parseResetCredit(_ value: Any) -> ResetCredit? {
        guard let row = value as? [String: Any],
              let rawID = opaqueID(row["id"]),
              let resetType = trimmedNonemptyString(row["resetType"], maximumLength: 120),
              let grantedAt = parseOptionalTimestamp(row, key: "grantedAt"),
              let expiresAt = parseOptionalTimestamp(row, key: "expiresAt") else {
            return nil
        }
        let status = ResetCreditStatus(rawValue: (row["status"] as? String) ?? "") ?? .unknown
        let title = trimmedNonemptyString(row["title"], maximumLength: 120)
        return ResetCredit(
            fingerprint: fingerprint(rawID),
            resetType: resetType,
            status: status,
            grantedAt: grantedAt,
            grantTimeSource: grantedAt == nil ? .unknown : .provider,
            expiresAt: expiresAt,
            title: title
        )
    }

    private static func parseOptionalTimestamp(_ row: [String: Any], key: String) -> Date?? {
        guard let value = row[key], !(value is NSNull) else { return .some(nil) }
        guard let seconds = readNumber(value),
              seconds.isFinite,
              seconds >= 946_684_800,
              seconds <= 4_102_444_800 else {
            return nil
        }
        return .some(Date(timeIntervalSince1970: seconds))
    }

    private static func trimmedNonemptyString(_ value: Any?, maximumLength: Int) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maximumLength))
    }

    private static func opaqueID(_ value: Any?) -> String? {
        guard let value = value as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.utf8.count <= 16_384 else {
            return nil
        }
        return value
    }

    private static func fingerprint(_ rawID: String) -> String {
        SHA256.hash(data: Data(rawID.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func resetCreditSort(_ lhs: ResetCredit, _ rhs: ResetCredit) -> Bool {
        switch (lhs.expiresAt, rhs.expiresAt) {
        case let (left?, right?) where left != right: return left < right
        case (.some, nil): return true
        case (nil, .some): return false
        default: break
        }
        switch (lhs.grantedAt, rhs.grantedAt) {
        case let (left?, right?) where left != right: return left < right
        case (.some, nil): return true
        case (nil, .some): return false
        default: return lhs.fingerprint < rhs.fingerprint
        }
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
