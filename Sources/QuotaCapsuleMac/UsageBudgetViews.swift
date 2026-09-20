import SwiftUI
import QuotaCapsuleCore

struct UsageBudgetCard: View {
    @ObservedObject var store: QuotaStore
    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UsageBudgetSummary(budget: store.usageBudgetState.result,
                plan: store.usageBudgetState.plan, copy: store.budgetCopy)
            Button(store.usageBudgetState.plan == nil ? store.budgetCopy.setup : store.budgetCopy.edit) {
                editing = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $editing) {
            UsagePlanEditor(plan: store.usageBudgetState.plan ?? UsagePlan(), copy: store.budgetCopy) { plan in
                store.saveUsagePlan(plan)
                editing = false
            }
        }
    }
}

struct UsageBudgetSummary: View {
    let budget: UsageBudget
    let plan: UsagePlan?
    let copy: BudgetCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.title).font(.headline)
            if plan == nil {
                Text(copy.explanation)
                Text(copy.text("先确认通常能使用的时间。", "先確認通常能使用的時間。", "Confirm your available hours first."))
            } else if budget.state == .unavailable {
                Text(copy.text("预算暂停，等待有效额度。", "預算暫停，等待有效額度。", "Budget paused. Awaiting valid quota."))
            } else if budget.state == .noSession {
                Text(copy.text("刷新前没有安排使用时段。", "刷新前沒有安排使用時段。", "No session before the quota deadline."))
                Text(copy.text("可以修改计划，安排剩余额度。", "可以修改計畫，安排剩餘額度。", "Edit your plan to allocate the remainder."))
            } else {
                Text(budget.state == .upcoming
                     ? copy.text("下个时段预计可用", "下個時段預計可用", "Next session allocation")
                     : copy.text("本时段还可用", "本時段還可用", "Available this session"))
                Text(copy.percent(budget.allowance ?? 0))
                    .font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                Text(copy.text("占完整周额度的比例", "佔完整週額度的比例", "Share of the full weekly quota"))
                    .font(.caption).foregroundStyle(.secondary)
                if let anchor = budget.anchor {
                    Text(copy.text("本段分配：", "本段分配：", "Allocated: ") + copy.percent(anchor.allocation))
                    Text(copy.text("分配后已用：", "分配後已用：", "Used since allocation: ") + copy.percent(budget.consumed))
                }
                if let session = budget.session {
                    Text((budget.state == .upcoming ? copy.text("开始：", "開始：", "Starts: ") : copy.text("结束：", "結束：", "Ends: ")) + copy.date(budget.state == .upcoming ? session.start : session.end))
                }
                Text(copy.text("刷新前可用时间：", "刷新前可用時間：", "Planned hours before deadline: ") + String(format: "%.1f h", budget.remainingHours))
                if budget.state == .allocatedSpent {
                    Text(copy.text("继续使用会占用后续时段的额度。", "繼續使用會佔用後續時段的額度。", "Further use draws from later sessions."))
                }
                if budget.state == .reserved {
                    Text(copy.text("剩余额度已达到你设置的预留量。", "剩餘額度已達到你設定的預留量。", "Remaining quota is at your reserve."))
                }
                Text(copy.text("本时段内分配固定。", "本時段內分配固定。", "Fixed within this session."))
                    .font(.caption).foregroundStyle(.secondary)
                Text(copy.text("修改计划会重新分配。", "修改計畫會重新分配。", "Edit the plan to reallocate."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let plan {
                Text(copy.text("预留：", "預留：", "Reserve: ") + copy.percent(plan.reservePercent))
                    .font(.caption)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UsagePlanEditor: View {
    @State var plan: UsagePlan
    let copy: BudgetCopy
    let save: (UsagePlan) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy.edit).font(.title2.bold())
            Text(copy.text("确认时段后，保存并分配预算。", "確認時段後，儲存並分配預算。", "Confirm your hours, then save."))
                .fixedSize(horizontal: false, vertical: true)
            Form {
                Picker(copy.text("开始时间", "開始時間", "Start time"), selection: $plan.startHour) {
                    ForEach(0..<24) { h in Text(String(format: "%02d:00", h)).tag(h) }
                }
                Picker(copy.text("结束时间", "結束時間", "End time"), selection: $plan.endHour) {
                    ForEach(0..<24) { h in Text(String(format: "%02d:00", h)).tag(h) }
                }
                Text(copy.text("结束早于开始：跨夜；时间相同：全天。", "結束早於開始：跨夜；時間相同：全天。", "Earlier end: overnight. Equal hours: full day."))
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
                Stepper(value: $plan.reservePercent, in: 0...100, step: 5) {
                    Text(copy.text("保留额度 ", "保留額度 ", "Reserve ") + copy.percent(plan.reservePercent))
                }
                Picker(copy.text("今天的任务量", "今天的任務量", "Today's workload"), selection: $plan.todayWeight) {
                    Text(copy.text("较少（0.5 倍）", "較少（0.5 倍）", "Light (0.5×)")).tag(0.5)
                    Text(copy.text("普通（1 倍）", "普通（1 倍）", "Normal (1×)")).tag(1.0)
                    Text(copy.text("较多（2 倍）", "較多（2 倍）", "Heavy (2×)")).tag(2.0)
                }
            }
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    Toggle(dayName(day), isOn: Binding(get: { plan.weekdays.contains(day) }, set: {
                        if $0 { plan.weekdays.insert(day) } else { plan.weekdays.remove(day) }
                    })).toggleStyle(.button).controlSize(.small)
                }
            }
            Text(copy.text("按设备本地时区计算。\n跨夜时段归开始日。", "按裝置本地時區計算。\n跨夜時段歸開始日。", "Uses this device's time zone.\nOvernight sessions belong to their start date."))
                .font(.caption).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(copy.text("取消", "取消", "Cancel")) { dismiss() }
                Spacer()
                Button(copy.text("保存并重新分配", "儲存並重新分配", "Save & reallocate")) {
                    plan.weightDate = UsageBudgetPlanner.dayKey(Date(), calendar: .current)
                    save(plan)
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            if plan.weightDate != UsageBudgetPlanner.dayKey(Date(), calendar: .current) { plan.todayWeight = 1 }
        }
    }

    private func dayName(_ day: Int) -> String {
        if copy.locale == .en { return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][day - 1] }
        return ["日", "一", "二", "三", "四", "五", "六"][day - 1]
    }
}
