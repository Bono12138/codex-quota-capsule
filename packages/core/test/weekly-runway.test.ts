import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import {
  analyzeWeeklyQuality,
  predictWeeklyRunway,
  type AgentQuotaSnapshot,
  type WeeklyQuotaReading,
} from "../src/index";

type FixtureCase = {
  id: string;
  snapshot: { usedPercent: number; remainingPercent: number; resetsAt: string };
  readings: Array<{ fetchedAt: string; usedPercent: number; resetsAt: string }>;
  expected: {
    qualityState: string;
    cycleCount: number;
    forecastState: string;
    sustainableRate?: number;
    projectedLower?: number;
    projectedUpper?: number;
  };
};

const fixture = JSON.parse(
  readFileSync(resolve(process.cwd(), "fixtures/weekly-runway-cases.json"), "utf8"),
) as { now: string; cases: FixtureCase[] };

describe("shared weekly runway fixtures", () => {
  for (const testCase of fixture.cases) {
    it(testCase.id, () => {
      const now = new Date(fixture.now);
      const snapshot: AgentQuotaSnapshot = {
        provider: "codex",
        sourceStatus: "ok",
        fetchedAt: now,
        weeklyWindow: {
          label: "weekly",
          windowMinutes: 10_080,
          usedPercent: testCase.snapshot.usedPercent,
          remainingPercent: testCase.snapshot.remainingPercent,
          resetsAt: new Date(testCase.snapshot.resetsAt),
        },
      };
      const readings: WeeklyQuotaReading[] = testCase.readings.map((reading) => ({
        provider: "codex",
        sourceStatus: "ok",
        fetchedAt: new Date(reading.fetchedAt),
        windowMinutes: 10_080,
        usedPercent: reading.usedPercent,
        remainingPercent: 100 - reading.usedPercent,
        resetsAt: new Date(reading.resetsAt),
      }));

      const quality = analyzeWeeklyQuality(readings, now);
      const forecast = predictWeeklyRunway(snapshot, quality, now);

      expect(quality.state).toBe(testCase.expected.qualityState);
      expect(new Set(quality.observations.map((observation) => observation.cycleID)).size).toBe(testCase.expected.cycleCount);
      expect(forecast.state).toBe(testCase.expected.forecastState);
      if (testCase.expected.sustainableRate !== undefined) {
        expect(forecast.sustainableRatePerDay).toBeCloseTo(testCase.expected.sustainableRate, 9);
      }
      if (testCase.expected.projectedLower !== undefined) {
        expect(forecast.projectedRemainingBandAtReset?.lower).toBeCloseTo(testCase.expected.projectedLower, 9);
        expect(forecast.projectedRemainingBandAtReset?.upper).toBeCloseTo(testCase.expected.projectedUpper!, 9);
      }
    });
  }
});
