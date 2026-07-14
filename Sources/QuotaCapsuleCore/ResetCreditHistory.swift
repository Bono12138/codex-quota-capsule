import Foundation

public enum ResetCreditLifecycle: String, Codable, Equatable, Sendable {
    case available
    case expired
    case likelyRedeemed
    case disappearedUnknown
}

public enum ResetCreditLifecycleClassifier {
    public static func classifyDisappearance(
        expiresAt: Date?,
        observedAt: Date,
        compatibleResetConfirmed: Bool
    ) -> ResetCreditLifecycle {
        if let expiresAt, expiresAt <= observedAt { return .expired }
        return compatibleResetConfirmed ? .likelyRedeemed : .disappearedUnknown
    }
}

public struct ResetCreditHistoryRecord: Equatable, Sendable {
    public let fingerprint: String
    public let resetType: String
    public let safeTitle: String?
    public let grantedAt: Date?
    public let grantTimeSource: ResetCreditGrantTimeSource
    public let expiresAt: Date?
    public let firstSeenAt: Date
    public let lastSeenAt: Date
    public let latestStatus: ResetCreditStatus
    public let lifecycle: ResetCreditLifecycle
    public let sampleCount: Int

    public init(
        fingerprint: String,
        resetType: String,
        safeTitle: String?,
        grantedAt: Date?,
        grantTimeSource: ResetCreditGrantTimeSource,
        expiresAt: Date?,
        firstSeenAt: Date,
        lastSeenAt: Date,
        latestStatus: ResetCreditStatus,
        lifecycle: ResetCreditLifecycle,
        sampleCount: Int
    ) {
        self.fingerprint = fingerprint
        self.resetType = resetType
        self.safeTitle = safeTitle
        self.grantedAt = grantedAt
        self.grantTimeSource = grantTimeSource
        self.expiresAt = expiresAt
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.latestStatus = latestStatus
        self.lifecycle = lifecycle
        self.sampleCount = sampleCount
    }
}

public struct ResetCreditBankRun: Equatable, Sendable {
    public let signature: String
    public let firstObservedAt: Date
    public let lastObservedAt: Date
    public let sampleCount: Int
    public let availableCount: Int
    public let detailCount: Int?
    public let detailState: ResetCreditDetailState

    public init(
        signature: String,
        firstObservedAt: Date,
        lastObservedAt: Date,
        sampleCount: Int,
        availableCount: Int,
        detailCount: Int?,
        detailState: ResetCreditDetailState
    ) {
        self.signature = signature
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
        self.sampleCount = sampleCount
        self.availableCount = availableCount
        self.detailCount = detailCount
        self.detailState = detailState
    }
}
