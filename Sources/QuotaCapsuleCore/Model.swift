import Foundation

public enum SourceStatus: Equatable, Sendable {
    case ok
    case stale
    case error
}

public struct QuotaWindow: Equatable, Sendable {
    public let label: String
    public let windowMinutes: Int
    public let usedPercent: Int
    public let remainingPercent: Int
    public let resetsAt: Date

    public init(label: String, windowMinutes: Int, usedPercent: Int, remainingPercent: Int, resetsAt: Date) {
        self.label = label
        self.windowMinutes = windowMinutes
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
    }
}

public struct AgentQuotaSnapshot: Equatable, Sendable {
    public let provider: String
    public let sourceStatus: SourceStatus
    public let fetchedAt: Date
    public let shortWindow: QuotaWindow?
    public let weeklyWindow: QuotaWindow?
    public let errorMessage: String?

    public init(
        provider: String,
        sourceStatus: SourceStatus,
        fetchedAt: Date,
        shortWindow: QuotaWindow?,
        weeklyWindow: QuotaWindow?,
        errorMessage: String?
    ) {
        self.provider = provider
        self.sourceStatus = sourceStatus
        self.fetchedAt = fetchedAt
        self.shortWindow = shortWindow
        self.weeklyWindow = weeklyWindow
        self.errorMessage = errorMessage
    }
}

public enum CapsuleLevel: Equatable, Sendable {
    case safe
    case watch
    case danger
    case unknown
}

public struct CapsulePrediction: Equatable, Sendable {
    public let level: CapsuleLevel
    public let canReachReset: Bool?
    public let elapsedPercent: Int?
    public let quotaUsedPercent: Int?
    public let projectedRemainingAtReset: Int?
    public let estimatedEmptyAt: Date?
    public let headline: String
    public let detail: String

    public init(
        level: CapsuleLevel,
        canReachReset: Bool?,
        elapsedPercent: Int?,
        quotaUsedPercent: Int?,
        projectedRemainingAtReset: Int?,
        estimatedEmptyAt: Date?,
        headline: String,
        detail: String
    ) {
        self.level = level
        self.canReachReset = canReachReset
        self.elapsedPercent = elapsedPercent
        self.quotaUsedPercent = quotaUsedPercent
        self.projectedRemainingAtReset = projectedRemainingAtReset
        self.estimatedEmptyAt = estimatedEmptyAt
        self.headline = headline
        self.detail = detail
    }
}

