import Foundation

public enum SourceStatus: Equatable, Sendable {
    case ok
    case stale
    case error
}

public struct QuotaWindow: Equatable, Sendable {
    public let label: String
    public let windowMinutes: Int
    public let usedPercent: Double
    public let remainingPercent: Double
    public let resetsAt: Date

    public init(label: String, windowMinutes: Int, usedPercent: Double, remainingPercent: Double, resetsAt: Date) {
        self.label = label
        self.windowMinutes = windowMinutes
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
    }
}

public struct WeeklyQuotaReading: Equatable, Sendable {
    public let provider: String
    public let sourceStatus: SourceStatus
    public let fetchedAt: Date
    public let windowMinutes: Int
    public let usedPercent: Double
    public let remainingPercent: Double
    public let resetsAt: Date
    public let errorMessage: String?

    public init(
        provider: String,
        sourceStatus: SourceStatus,
        fetchedAt: Date,
        windowMinutes: Int,
        usedPercent: Double,
        remainingPercent: Double,
        resetsAt: Date,
        errorMessage: String?
    ) {
        self.provider = provider
        self.sourceStatus = sourceStatus
        self.fetchedAt = fetchedAt
        self.windowMinutes = windowMinutes
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
        self.errorMessage = errorMessage
    }
}

public enum WeeklyQualityState: String, Codable, Equatable, Sendable {
    case stable
    case calibrating
    case unstable
    case stale
    case unavailable
}

public enum WeeklyQualityFlag: String, Codable, Equatable, Hashable, Sendable {
    case resetCandidate
    case correction
    case alternatingStream
    case resetJitter
    case staleSource
}

public struct WeeklyObservation: Equatable, Sendable {
    public let fetchedAt: Date
    public let canonicalResetAt: Date
    public let usedPercent: Double
    public let remainingPercent: Double
    public let cycleID: Int
    public let segmentID: Int
    public let qualityFlags: Set<WeeklyQualityFlag>

    public init(
        fetchedAt: Date,
        canonicalResetAt: Date,
        usedPercent: Double,
        remainingPercent: Double,
        cycleID: Int,
        segmentID: Int,
        qualityFlags: Set<WeeklyQualityFlag> = []
    ) {
        self.fetchedAt = fetchedAt
        self.canonicalResetAt = canonicalResetAt
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.cycleID = cycleID
        self.segmentID = segmentID
        self.qualityFlags = qualityFlags
    }
}

public struct WeeklyQualityResult: Equatable, Sendable {
    public let state: WeeklyQualityState
    public let observations: [WeeklyObservation]
    public let canonicalResetAt: Date?
    public let flags: Set<WeeklyQualityFlag>

    public init(
        state: WeeklyQualityState,
        observations: [WeeklyObservation],
        canonicalResetAt: Date?,
        flags: Set<WeeklyQualityFlag>
    ) {
        self.state = state
        self.observations = observations
        self.canonicalResetAt = canonicalResetAt
        self.flags = flags
    }
}

public struct AgentQuotaSnapshot: Equatable, Sendable {
    public let provider: String
    public let sourceStatus: SourceStatus
    public let fetchedAt: Date
    public let weeklyWindow: QuotaWindow?
    public let errorMessage: String?

    public init(
        provider: String,
        sourceStatus: SourceStatus,
        fetchedAt: Date,
        weeklyWindow: QuotaWindow?,
        errorMessage: String?
    ) {
        self.provider = provider
        self.sourceStatus = sourceStatus
        self.fetchedAt = fetchedAt
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
