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

    private var timer: Timer?

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
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        Task.detached(priority: .utility) {
            let snapshot = CodexAppServerClient.fetchCurrent(timeoutSeconds: 8)
            let now = Date()
            let prediction = QuotaPredictor.predict(snapshot: snapshot, now: now)
            let model = CapsuleDisplayModel.make(prediction: prediction)

            await MainActor.run {
                self.snapshot = snapshot
                self.prediction = prediction
                self.displayModel = model
                self.lastRefreshText = QuotaStore.timeFormatter.string(from: now)
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

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
