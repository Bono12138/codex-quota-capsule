import AppKit
import SwiftUI
import Testing
import QuotaCapsuleCore
@testable import QuotaCapsuleMac

@Suite("Budget rendering")
@MainActor
struct UsageBudgetRenderTests {
    @Test func renderSyntheticBudgetCards() throws {
        guard let directory = ProcessInfo.processInfo.environment["QUOTA_RENDER_DIRECTORY"] else { return }
        let url = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let now = ISO8601DateFormatter().date(from: "2026-09-20T18:00:00Z")!
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let plan = UsagePlan(startHour: 18, endHour: 22)
        let budget = UsageBudgetPlanner.evaluate(plan: plan, anchor: nil, remaining: 60,
            resetAt: now.addingTimeInterval(2 * 86400 + 14400), horizon: now.addingTimeInterval(2 * 86400 + 14400), now: now, calendar: calendar)
        for locale in [QuotaLocale.zhHans, .zhHant, .en] {
            for width in [308.0, 388.0, 528.0] {
                let view = UsageBudgetSummary(budget: budget, plan: plan, copy: BudgetCopy(locale: locale))
                    .padding(16).frame(width: width).background(Color.white).foregroundStyle(.black)
                    .environment(\.colorScheme, .light)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = try #require(renderer.nsImage)
                let data = try #require(image.tiffRepresentation)
                let bitmap = try #require(NSBitmapImageRep(data: data))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: url.appendingPathComponent("budget-\(locale.rawValue)-\(Int(width)).png"))
            }
            for scheme in [ColorScheme.light, .dark] {
                let view = HStack(alignment: .top, spacing: 12) {
                    UsageBudgetSummary(budget: .unavailable, plan: nil, copy: BudgetCopy(locale: locale))
                        .frame(width: 280)
                    VStack(spacing: 24) {
                        UsageBudgetSummary(budget: .unavailable, plan: plan, copy: BudgetCopy(locale: locale))
                        UsageBudgetSummary(budget: UsageBudgetPlanner.evaluate(plan: plan, anchor: nil, remaining: 0,
                            resetAt: now.addingTimeInterval(3600), horizon: now.addingTimeInterval(3600), now: now, calendar: calendar),
                            plan: plan, copy: BudgetCopy(locale: locale))
                    }.frame(width: 280)
                    VStack(spacing: 24) {
                        UsageBudgetSummary(budget: UsageBudgetPlanner.evaluate(plan: plan, anchor: nil, remaining: 60,
                            resetAt: now.addingTimeInterval(86400), horizon: now.addingTimeInterval(86400), now: now.addingTimeInterval(18000), calendar: calendar),
                            plan: plan, copy: BudgetCopy(locale: locale))
                        UsageBudgetSummary(budget: UsageBudgetPlanner.evaluate(plan: plan, anchor: budget.anchor, remaining: 30,
                            resetAt: now.addingTimeInterval(2 * 86400 + 14400), horizon: now.addingTimeInterval(2 * 86400 + 14400), now: now.addingTimeInterval(60), calendar: calendar),
                            plan: plan, copy: BudgetCopy(locale: locale))
                    }.frame(width: 280)
                }.padding(16)
                    .background(scheme == .light ? Color.white : Color.black)
                    .environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = try #require(renderer.nsImage)
                let data = try #require(image.tiffRepresentation)
                let bitmap = try #require(NSBitmapImageRep(data: data))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: url.appendingPathComponent("states-\(locale.rawValue)-\(scheme).png"))
            }
        }
    }
}
