@testable import QuotaCapsuleMac
import Foundation
import QuotaCapsuleCore
import Testing

@Suite("Capsule tone contrast")
struct CapsuleTonePaletteTests {
    @Test("watch tone uses a visible outlined treatment")
    func watchToneUsesOutlinedTreatment() {
        let treatment = CapsuleTonePalette.treatment(for: .watch)

        #expect(treatment.fillOpacity > 0)
        #expect(treatment.strokeOpacity >= 0.65)
        #expect(treatment.strokeWidth >= 1)
    }

    @Test("status accents remain readable on both capsule surfaces")
    func statusAccentsMeetTextContrast() {
        for level in [CapsuleLevel.safe, .watch, .danger, .unknown] {
            let light = CapsuleTonePalette.components(for: level, scheme: .light)
            let dark = CapsuleTonePalette.components(for: level, scheme: .dark)

            #expect(contrast(light, CapsuleRGB(red: 0.92, green: 0.96, blue: 0.95)) >= 4.5)
            #expect(contrast(dark, CapsuleRGB(red: 0.10, green: 0.12, blue: 0.13)) >= 4.5)
        }
    }

    private func contrast(_ foreground: CapsuleRGB, _ background: CapsuleRGB) -> Double {
        let lighter = max(luminance(foreground), luminance(background))
        let darker = min(luminance(foreground), luminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ color: CapsuleRGB) -> Double {
        0.2126 * linear(color.red)
            + 0.7152 * linear(color.green)
            + 0.0722 * linear(color.blue)
    }

    private func linear(_ value: Double) -> Double {
        value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
}
