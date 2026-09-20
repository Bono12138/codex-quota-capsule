import Foundation
import QuotaCapsuleCore

/// Plan settings stay on this device. Anchors survive app restarts within a session.
@MainActor
final class UsageBudgetState {
    private let defaults: UserDefaults
    private let planKey: String
    private let anchorKey: String
    private(set) var plan: UsagePlan?
    private(set) var usesDefaultPlan: Bool
    private(set) var usesDeadlineFallback = false
    private(set) var anchor: UsageBudgetAnchor?
    private(set) var result: UsageBudget = .unavailable

    init(defaults: UserDefaults, prefix: String) {
        self.defaults = defaults
        planKey = prefix + ".usagePlan.v1"
        anchorKey = prefix + ".usageBudgetAnchor.v1"
        let saved = defaults.data(forKey: planKey).flatMap { try? JSONDecoder().decode(UsagePlan.self, from: $0) }
        usesDefaultPlan = saved == nil
        plan = saved ?? UsagePlan()
        anchor = defaults.data(forKey: anchorKey).flatMap { try? JSONDecoder().decode(UsageBudgetAnchor.self, from: $0) }
    }

    func save(_ plan: UsagePlan) {
        self.plan = plan
        usesDefaultPlan = false
        anchor = nil
        defaults.set(try? JSONEncoder().encode(plan), forKey: planKey)
        defaults.removeObject(forKey: anchorKey)
    }

    func restoreDefault() {
        plan = UsagePlan()
        usesDefaultPlan = true
        anchor = nil
        defaults.removeObject(forKey: planKey)
        defaults.removeObject(forKey: anchorKey)
    }

    func update(snapshot: AgentQuotaSnapshot, confirming: Bool, now: Date, calendar: Calendar = .current) {
        usesDeadlineFallback = false
        guard var plan, snapshot.sourceStatus == .ok, !confirming,
              now.timeIntervalSince(snapshot.fetchedAt) >= -60,
              now.timeIntervalSince(snapshot.fetchedAt) <= 180,
              let window = snapshot.weeklyWindow,
              let horizon = WeeklyRunwayPredictor.burnHorizon(snapshot: snapshot, now: now) else {
            result = .unavailable
            return
        }
        if usesDefaultPlan, UsageBudgetPlanner.sessions(plan: plan, from: now, to: horizon.at, calendar: calendar).isEmpty {
            // An imminent deadline still has a useful default allowance outside daytime hours.
            plan = UsagePlan(startHour: 0, endHour: 0)
            usesDeadlineFallback = true
        }
        // A reading from before a session/deadline transition cannot fund a new allocation.
        if let anchor, anchor.horizon <= now, snapshot.fetchedAt < anchor.horizon {
            result = .unavailable
            return
        }
        let slots = UsageBudgetPlanner.sessions(plan: plan, from: snapshot.fetchedAt, to: horizon.at, calendar: calendar)
        if let slot = slots.first(where: { $0.start <= now && now < $0.end }), slot.start > snapshot.fetchedAt {
            result = .unavailable
            return
        }
        result = UsageBudgetPlanner.evaluate(plan: plan, anchor: anchor, remaining: window.remainingPercent,
            resetAt: window.resetsAt, horizon: horizon.at, now: now, calendar: calendar)
        if result.anchor != anchor {
            anchor = result.anchor
            defaults.set(anchor.flatMap { try? JSONEncoder().encode($0) }, forKey: anchorKey)
        }
    }
}

struct BudgetCopy {
    let locale: QuotaLocale
    func text(_ zh: String, _ hant: String, _ en: String) -> String {
        switch locale { case .zhHans: zh; case .zhHant: hant; case .en: en }
    }
    var title: String { text("使用计划", "使用計畫", "Usage plan") }
    var edit: String { text("自定义时段（可选）", "自訂時段（可選）", "Customize hours (optional)") }
    var setup: String { text("设置使用时段", "設定使用時段", "Set usage hours") }
    var explanation: String {
        text("按你计划的时段分配周额度。", "按你計畫的時段分配週額度。", "Allocate quota to planned hours.")
    }
    func status(_ budget: UsageBudget, configured: Bool) -> String {
        guard configured else { return setup }
        switch budget.state {
        case .active: return text("按计划使用", "按計畫使用", "Session budget")
        case .upcoming: return text("下个使用时段", "下個使用時段", "Next session")
        case .noSession: return text("需要安排时段", "需要安排時段", "Add a session")
        case .allocatedSpent: return text("时段预算已用完", "時段預算已用完", "Session spent")
        case .reserved: return text("已到预留额度", "已到預留額度", "Reserve reached")
        case .unavailable: return text("等待有效读数", "等待有效讀數", "Awaiting data")
        }
    }
    func percent(_ value: Double) -> String { String(format: "%.1f%%", floor(max(0, value) * 10) / 10) }
    func date(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: locale == .en ? "en_US" : locale == .zhHant ? "zh_TW" : "zh_CN")
        f.dateFormat = locale == .en ? "MMM d, HH:mm" : "M月d日 HH:mm"
        return f.string(from: date)
    }
}
