import AppKit
import SwiftUI
import Testing
import QuotaCapsuleCore
@testable import QuotaCapsuleMac

@Suite("Dual progress presentation")
@MainActor
struct ProgressComparisonTests {
    @Test func limitingWindowAndMissingDataOverrideHumor() {
        #expect(PaceMessage.classify(used: 20, available: 70, active: true, fiveHourRemaining: 5) == .fiveHour)
        #expect(PaceMessage.classify(used: 95, available: 70, active: true, fiveHourRemaining: 80) == .low)
        #expect(PaceMessage.classify(used: 20, available: 70, active: false, fiveHourRemaining: 80) == .resting)
        #expect(PaceMessage.classify(used: 20, available: 70, active: true, fiveHourRemaining: 80) == .abundant)
        #expect(PaceMessage.classify(used: 70, available: 20, active: true, fiveHourRemaining: nil) == .fast)
        #expect(PaceMessage.classify(used: 25, available: 30, active: true, fiveHourRemaining: nil) == .balanced)
        #expect(PaceMessage.classify(used: .nan, available: 30, active: true, fiveHourRemaining: nil) == nil)
        #expect(PaceMessage.classify(used: 25, available: nil, active: true, fiveHourRemaining: nil) == nil)
    }
    @Test func messagesAreStableLocalizedAndVaried() {
        for locale in [QuotaLocale.zhHans, .zhHant, .en] {
            let copy = BudgetCopy(locale: locale)
            for message in PaceMessage.allCases {
                #expect(message.text(copy: copy, seed: 123) == message.text(copy: copy, seed: 123))
                #expect(!message.text(copy: copy, seed: -1).isEmpty)
                if message != .fiveHour {
                    #expect(Set((0..<3).map { message.text(copy: copy, seed: $0) }).count == 3)
                }
            }
        }
    }

    @Test func renderClockOrderAndUnknownStates() throws {
        guard let directory = ProcessInfo.processInfo.environment["QUOTA_RENDER_DIRECTORY"] else { return }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for locale in [QuotaLocale.zhHans, .zhHant, .en] {
            for scheme in [ColorScheme.light, .dark] {
                let view = HStack(alignment: .top, spacing: 20) {
                    ForEach([266.0, 346.0, 486.0], id: \.self) { width in
                        VStack(spacing: 24) {
                            ProgressComparisonView(natural: 40, available: 60, used: 25, copy: BudgetCopy(locale: locale), compact: true)
                            ProgressComparisonView(natural: 65, available: 40, used: 90, copy: BudgetCopy(locale: locale))
                            ProgressComparisonView(natural: 100, available: 100, used: 100, copy: BudgetCopy(locale: locale))
                            ProgressComparisonView(natural: nil, available: nil, used: nil, copy: BudgetCopy(locale: locale))
                        }.frame(width: width)
                    }
                }.padding(20).background(scheme == .light ? Color.white : Color.black)
                    .environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = try #require(renderer.nsImage)
                let tiff = try #require(image.tiffRepresentation)
                let bitmap = try #require(NSBitmapImageRep(data: tiff))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("dual-\(locale.rawValue)-\(scheme).png"))
            }
        }
    }
}
