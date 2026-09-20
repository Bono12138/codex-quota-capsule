import SwiftUI
import QuotaCapsuleCore

/// Identical track bounds preserve the comparison even when labels have different lengths.
struct ProgressComparisonView: View {
    let natural: Double?
    let available: Double?
    let used: Double?
    let copy: BudgetCopy
    var compact = false
    var inline = false
    @Environment(\.colorScheme) private var scheme

    private var clockColor: Color { scheme == .dark
        ? Color(red: 0.65, green: 0.77, blue: 0.94) : Color(red: 0.33, green: 0.45, blue: 0.61) }
    private var availableColor: Color { scheme == .dark
        ? Color(red: 0.22, green: 0.84, blue: 0.71) : Color(red: 0.0, green: 0.47, blue: 0.39) }
    private let quotaColor = Color.indigo
    private func percent(_ n: Double?) -> String {
        n.flatMap { $0.isFinite ? "\(Int($0.rounded()))%" : nil } ?? "—"
    }

    var body: some View {
        if inline {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(copy.text("时间", "時間", "Time")).frame(width: 28, alignment: .leading)
                    track(time: true)
                    Text(percent(available)).frame(width: 32, alignment: .trailing)
                }
                HStack(spacing: 6) {
                    Text(copy.text("已用", "已用", "Used")).frame(width: 28, alignment: .leading)
                    track(time: false)
                    Text(percent(used)).frame(width: 32, alignment: .trailing)
                }
            }
            .font(.system(size: 10, weight: .medium)).monospacedDigit()
            .help(copy.text("自然时间 ", "自然時間 ", "Clock ") + percent(natural)
                + " · " + copy.text("可用时间 ", "可用時間 ", "Usable ") + percent(available))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(copy.text("自然时间 ", "自然時間 ", "Clock ") + percent(natural)
                + " · " + copy.text("可用时间 ", "可用時間 ", "Usable ") + percent(available)
                + " · " + copy.text("额度已用 ", "額度已用 ", "Quota used ") + percent(used))
        } else {
        VStack(spacing: compact ? 7 : 16) {
            VStack(spacing: 5) {
                HStack {
                    Text(copy.text("时间", "時間", "Time")).fontWeight(.semibold)
                    Spacer(minLength: 4)
                    Text(copy.text("自然 ", "自然 ", "Clock ") + percent(natural)).foregroundStyle(clockColor)
                    Text(copy.text("可用 ", "可用 ", "Usable ") + percent(available)).foregroundStyle(availableColor)
                }
                track(time: true)
            }
            VStack(spacing: 5) {
                HStack {
                    Text(copy.text("额度已用", "額度已用", "Quota used")).fontWeight(.semibold)
                    Spacer()
                    Text(percent(used)).foregroundStyle(quotaColor).fontWeight(.semibold)
                }
                track(time: false)
            }
        }
        .font(.system(size: compact ? 11 : 13))
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        }
    }

    private func track(time: Bool) -> some View {
        GeometryReader { g in
            let n = min(100, max(0, natural ?? 0)) / 100
            let a = min(100, max(0, available ?? 0)) / 100
            let q = min(100, max(0, used ?? 0)) / 100
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.10))
                if time {
                    Rectangle().fill(clockColor).frame(width: g.size.width * n)
                    if available != nil {
                        Rectangle().fill(availableColor)
                            .frame(width: g.size.width * max(0, a - n))
                            .offset(x: g.size.width * n)
                        // Distinct endpoint shapes remain legible without color perception.
                        Rectangle().fill(.primary).frame(width: 2)
                            .offset(x: max(0, min(g.size.width - 2, g.size.width * n)))
                        Circle().fill(availableColor).overlay(Circle().stroke(.background, lineWidth: 1.5))
                            .frame(width: g.size.height, height: g.size.height)
                            .offset(x: max(0, min(g.size.width - g.size.height, g.size.width * a - g.size.height / 2)))
                    }
                } else {
                    Rectangle().fill(quotaColor).frame(width: g.size.width * q)
                }
            }.clipShape(Capsule())
        }.frame(height: compact ? 7 : 11)
        .accessibilityHidden(true)
    }
}

enum PaceMessage: String, CaseIterable {
    case abundant, balanced, fast, low, resting, expiring, fiveHour

    static func classify(used: Double, available: Double?, active: Bool,
                         fiveHourRemaining: Double?, expiring: Bool = false) -> PaceMessage? {
        guard used.isFinite, (0...100).contains(used), let available,
              available.isFinite, (0...100).contains(available) else { return nil }
        if let fiveHourRemaining, fiveHourRemaining <= 10 { return .fiveHour }
        if used >= 90 { return .low }
        if expiring { return .expiring }
        if !active { return .resting }
        if used - available > 10 { return .fast }
        if used - available < -10 { return .abundant }
        return .balanced
    }

    func text(copy: BudgetCopy, seed: Int) -> String {
        let choices: [String]
        switch self {
        case .abundant: choices = [copy.text("额度还很能打", "額度還很能打", "Quota's chilling"), copy.text("任务可以加戏", "任務可以加戲", "Room for more"), copy.text("库存充足，别太客气", "庫存充足，別太客氣", "Plenty in the tank")]
        case .balanced: choices = [copy.text("节奏拿捏了", "節奏拿捏了", "Pace on point"), copy.text("这波操作很稳", "這波操作很穩", "Looking steady"), copy.text("主打一个从容", "主打一個從容", "Nice and steady")]
        case .fast: choices = [copy.text("油门有点深了", "油門有點深了", "Easy on the turbo"), copy.text("额度开始冒汗", "額度開始冒汗", "Quota's sweating"), copy.text("这波有点上强度", "這波有點上強度", "That's quite a pace")]
        case .low: choices = [copy.text("大招先留一手", "大招先留一手", "Save the big moves"), copy.text("进入省电模式", "進入省電模式", "Low-power vibes"), copy.text("余额：我尽力了", "餘額：我盡力了", "Running on fumes")]
        case .resting: choices = [copy.text("进入待机副本", "進入待機副本", "Side quest: rest"), copy.text("今天先存个档", "今天先存個檔", "Time to save your game"), copy.text("额度陪你摸会儿鱼", "額度陪你摸會兒魚", "Quota's on a break")]
        case .expiring: choices = [copy.text("券要下班了", "券要下班了", "Your reset pass clocks out soon"), copy.text("别把重置券养过期", "別把重置券養過期", "Check that reset pass"), copy.text("到点退场，记得用券", "到點退場，記得用券", "Reset pass: last call")]
        case .fiveHour: return copy.text("5 小时额度偏低", "5 小時額度偏低", "5h quota is low")
        }
        return choices[((seed % choices.count) + choices.count) % choices.count]
    }
}
