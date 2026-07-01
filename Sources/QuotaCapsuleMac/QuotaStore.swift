import Foundation
import SwiftUI
import QuotaCapsuleCore

@MainActor
final class QuotaStore: ObservableObject {
    @Published private(set) var snapshot: AgentQuotaSnapshot
    @Published private(set) var prediction: CapsulePrediction
    @Published private(set) var displayModel: CapsuleDisplayModel
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshText = "尚未刷新"
    @Published private(set) var lastAttemptText = "尚未尝试"
    @Published private(set) var lastErrorText: String?

    private var refreshTask: Task<Void, Never>?

    init() {
        let now = Date()
        let initial = AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .error,
            fetchedAt: now,
            shortWindow: nil,
            weeklyWindow: nil,
            errorMessage: "启动中，正在读取 Codex 额度。"
        )
        let initialPrediction = QuotaPredictor.predict(snapshot: initial, now: now)
        snapshot = initial
        prediction = initialPrediction
        displayModel = CapsuleDisplayModel.make(prediction: initialPrediction)

        refresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await MainActor.run {
                    self?.refresh()
                }
            }
        }
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        Task.detached(priority: .utility) {
            let snapshot = CodexAppServerClient.fetchCurrent()
            let now = Date()

            await MainActor.run {
                self.applyRefreshResult(snapshot, now: now)
                self.isRefreshing = false
            }
        }
    }

    var weeklyText: String {
        guard let weeklyWindow = snapshot.weeklyWindow else {
            return "未知"
        }
        return "\(weeklyWindow.remainingPercent)%"
    }

    var resetText: String {
        guard let resetsAt = snapshot.shortWindow?.resetsAt else {
            return "未知"
        }
        return QuotaPredictor.formatTime(resetsAt)
    }

    var sourceText: String {
        if snapshot.sourceStatus == .ok {
            if let lastErrorText {
                return "Codex app-server / rateLimits/read。继续显示 \(lastRefreshText) 数据；最近失败：\(lastErrorText)"
            }
            return "Codex app-server / rateLimits/read。成功更新：\(lastRefreshText)"
        }
        return "Codex app-server 暂时不可用\n\(lastErrorText ?? snapshot.errorMessage ?? "未知错误")"
    }

    var sourceNameText: String {
        "Codex app-server"
    }

    var sourceEndpointText: String {
        "rateLimits/read"
    }

    var sourceStatusText: String {
        if snapshot.sourceStatus == .ok {
            if lastErrorText != nil {
                return "显示上次成功数据"
            }
            return "实时读取成功"
        }
        return "读取失败"
    }

    var sourceNoteText: String {
        if snapshot.sourceStatus == .ok, let lastErrorText {
            return "最近失败：\(lastErrorText)"
        }
        if snapshot.sourceStatus == .ok {
            return "最近尝试 \(lastAttemptText)，每 60 秒自动刷新。"
        }
        return lastErrorText ?? snapshot.errorMessage ?? "未知错误"
    }

    var visibleStatusText: String {
        if isRefreshing && snapshot.sourceStatus != .ok {
            return "读取中"
        }
        return displayModel.statusLabel
    }

    var visibleCompactText: String {
        if isRefreshing && snapshot.sourceStatus != .ok {
            return "正在读取 Codex 额度"
        }
        return displayModel.defaultText
    }

    private func applyRefreshResult(_ newSnapshot: AgentQuotaSnapshot, now: Date) {
        lastAttemptText = QuotaStore.timeFormatter.string(from: now)

        if newSnapshot.sourceStatus == .ok {
            let newPrediction = QuotaPredictor.predict(snapshot: newSnapshot, now: now)
            snapshot = newSnapshot
            prediction = newPrediction
            displayModel = CapsuleDisplayModel.make(prediction: newPrediction)
            lastRefreshText = lastAttemptText
            lastErrorText = nil
            return
        }

        let cleanedError = QuotaStore.cleanError(newSnapshot.errorMessage)
        lastErrorText = cleanedError

        if snapshot.sourceStatus == .ok {
            let refreshedPrediction = QuotaPredictor.predict(snapshot: snapshot, now: now)
            prediction = refreshedPrediction
            displayModel = CapsuleDisplayModel.make(prediction: refreshedPrediction)
            return
        }

        let newPrediction = QuotaPredictor.predict(snapshot: newSnapshot, now: now)
        snapshot = newSnapshot
        prediction = newPrediction
        displayModel = CapsuleDisplayModel.make(prediction: newPrediction)
    }

    private static func cleanError(_ message: String?) -> String {
        guard let message, !message.isEmpty else {
            return "未知错误"
        }

        let firstLine = message
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\\n"#, with: " ")

        if firstLine.count <= 180 {
            return firstLine
        }
        return "\(firstLine.prefix(180))..."
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
