import Foundation

struct QuotaRefreshLifecycle: Sendable {
    private var nextAttempt = 0
    private(set) var activeAttempt: Int?

    var isActive: Bool {
        activeAttempt != nil
    }

    mutating func begin() -> Int? {
        guard activeAttempt == nil else { return nil }
        nextAttempt += 1
        activeAttempt = nextAttempt
        return nextAttempt
    }

    mutating func finish(_ attempt: Int) -> Bool {
        guard activeAttempt == attempt else { return false }
        activeAttempt = nil
        return true
    }

    mutating func expire(_ attempt: Int) -> Bool {
        finish(attempt)
    }
}

enum QuotaRefreshPolicy {
    static let fetchTimeoutSeconds: TimeInterval = 12
    static let maximumAttempts = 2
    static let retryDelaySeconds: TimeInterval = 1.25
    static let watchdogSeconds: TimeInterval = 30

    static var maximumExpectedFetchSeconds: TimeInterval {
        fetchTimeoutSeconds * Double(maximumAttempts)
            + retryDelaySeconds * Double(maximumAttempts - 1)
    }
}
