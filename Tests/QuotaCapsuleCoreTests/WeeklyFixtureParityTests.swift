@testable import QuotaCapsuleCore
import Foundation
import Testing

@Suite("Swift and TypeScript fixture parity")
struct WeeklyFixtureParityTests {
    private struct Fixture: Decodable {
        let now: String
        let cases: [FixtureCase]
    }

    private struct FixtureCase: Decodable {
        struct Snapshot: Decodable {
            let usedPercent: Double
            let remainingPercent: Double
            let resetsAt: String
        }
        struct Reading: Decodable {
            let fetchedAt: String
            let usedPercent: Double
            let resetsAt: String
        }
        struct Expected: Decodable {
            let qualityState: String
            let cycleCount: Int
            let forecastState: String
            let sustainableRate: Double?
            let projectedLower: Double?
            let projectedUpper: Double?
        }

        let id: String
        let snapshot: Snapshot
        let readings: [Reading]
        let expected: Expected
    }

    @Test("shared JSON cases produce the exact native results")
    func sharedCasesMatchNativeEngine() throws {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("fixtures/weekly-runway-cases.json")
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        let now = try parseDate(fixture.now)

        for testCase in fixture.cases {
            let resetsAt = try parseDate(testCase.snapshot.resetsAt)
            let snapshot = AgentQuotaSnapshot(
                provider: "codex",
                sourceStatus: .ok,
                fetchedAt: now,
                weeklyWindow: QuotaWindow(
                    label: "weekly",
                    windowMinutes: 10_080,
                    usedPercent: testCase.snapshot.usedPercent,
                    remainingPercent: testCase.snapshot.remainingPercent,
                    resetsAt: resetsAt
                ),
                errorMessage: nil
            )
            let readings = try testCase.readings.map { reading in
                WeeklyQuotaReading(
                    provider: "codex",
                    sourceStatus: .ok,
                    fetchedAt: try parseDate(reading.fetchedAt),
                    windowMinutes: 10_080,
                    usedPercent: reading.usedPercent,
                    remainingPercent: 100 - reading.usedPercent,
                    resetsAt: try parseDate(reading.resetsAt),
                    errorMessage: nil
                )
            }

            let quality = WeeklyQualityEngine.analyze(readings, now: now)
            let forecast = WeeklyRunwayPredictor.predict(snapshot: snapshot, quality: quality, now: now)
            let cycleCount = Set(quality.observations.map(\.cycleID)).count

            #expect(quality.state.rawValue == testCase.expected.qualityState, "quality mismatch in \(testCase.id)")
            #expect(cycleCount == testCase.expected.cycleCount, "cycle mismatch in \(testCase.id)")
            #expect(forecast.state.rawValue == testCase.expected.forecastState, "forecast mismatch in \(testCase.id)")
            if let expected = testCase.expected.sustainableRate {
                #expect(abs((forecast.sustainableRatePerDay ?? .nan) - expected) < 0.000_000_001, "sustainable rate mismatch in \(testCase.id)")
            }
            if let expected = testCase.expected.projectedLower {
                #expect(abs((forecast.projectedRemainingBandAtReset?.lower ?? .nan) - expected) < 0.000_000_001, "lower projection mismatch in \(testCase.id)")
                #expect(abs((forecast.projectedRemainingBandAtReset?.upper ?? .nan) - (testCase.expected.projectedUpper ?? .nan)) < 0.000_000_001, "upper projection mismatch in \(testCase.id)")
            }
        }
    }

    private func parseDate(_ value: String) throws -> Date {
        try Date.ISO8601FormatStyle().parse(value)
    }
}
