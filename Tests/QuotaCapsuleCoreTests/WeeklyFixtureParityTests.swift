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
            let windowMinutes: Int?
        }
        struct Expected: Decodable {
            let qualityState: String
            let cycleCount: Int
            let forecastState: String
            let usedPercent: Double?
            let confidence: String?
            let evidenceKinds: [String]?
            let sustainableRate: Double?
            let projectedLower: Double?
            let projectedUpper: Double?
            let last24Lower: Double?
            let last24Upper: Double?
            let ignoredShortWindow: Bool?
            let recentFasterThanCycle: Bool?
            let cycleFasterThanRecent: Bool?
            let exhaustionBeforeReset: Bool?
            let exhaustionAtNow: Bool?
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
                    windowMinutes: reading.windowMinutes ?? 10_080,
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
            if let expected = testCase.expected.confidence {
                #expect(forecast.confidence.rawValue == expected, "confidence mismatch in \(testCase.id)")
            }
            if let expected = testCase.expected.usedPercent {
                #expect(forecast.usedPercent == expected, "accepted used percent mismatch in \(testCase.id)")
            }
            if let expected = testCase.expected.evidenceKinds {
                #expect(forecast.paceEvidence.map { $0.kind.rawValue } == expected, "evidence mismatch in \(testCase.id)")
            }
            if let expected = testCase.expected.sustainableRate {
                #expect(abs((forecast.sustainableRatePerDay ?? .nan) - expected) < 0.000_000_001, "sustainable rate mismatch in \(testCase.id)")
            }
            if let expected = testCase.expected.projectedLower {
                #expect(abs((forecast.projectedRemainingBandAtReset?.lower ?? .nan) - expected) < 0.000_000_001, "lower projection mismatch in \(testCase.id)")
                #expect(abs((forecast.projectedRemainingBandAtReset?.upper ?? .nan) - (testCase.expected.projectedUpper ?? .nan)) < 0.000_000_001, "upper projection mismatch in \(testCase.id)")
            }
            if let expected = testCase.expected.last24Lower {
                #expect(abs((forecast.last24HourUsageBand?.lower ?? .nan) - expected) < 0.000_000_001, "last-24 lower mismatch in \(testCase.id)")
                #expect(abs((forecast.last24HourUsageBand?.upper ?? .nan) - (testCase.expected.last24Upper ?? .nan)) < 0.000_000_001, "last-24 upper mismatch in \(testCase.id)")
            }
            if testCase.expected.ignoredShortWindow == true {
                #expect(quality.observations.allSatisfy { $0.usedPercent != 90 }, "short window leaked into \(testCase.id)")
            }
            if testCase.expected.recentFasterThanCycle == true {
                #expect(midpoint(forecast.recentRateBandPerDay) > midpoint(forecast.cycleRateBandPerDay), "recent pace should be faster in \(testCase.id)")
            }
            if testCase.expected.cycleFasterThanRecent == true {
                #expect(midpoint(forecast.cycleRateBandPerDay) > midpoint(forecast.recentRateBandPerDay), "cycle pace should be faster in \(testCase.id)")
            }
            if testCase.expected.exhaustionBeforeReset == true {
                #expect(forecast.estimatedEmptyAtRange?.latest ?? .distantFuture < resetsAt, "exhaustion bound should precede reset in \(testCase.id)")
            }
            if testCase.expected.exhaustionAtNow == true {
                #expect(forecast.estimatedEmptyAtRange?.earliest == now, "exhausted lower bound mismatch in \(testCase.id)")
                #expect(forecast.estimatedEmptyAtRange?.latest == now, "exhausted upper bound mismatch in \(testCase.id)")
            }
        }
    }

    private func parseDate(_ value: String) throws -> Date {
        try Date.ISO8601FormatStyle().parse(value)
    }

    private func midpoint(_ band: PaceBand?) -> Double {
        guard let band else { return .nan }
        return (band.lower + band.upper) / 2
    }
}
