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
  readings: Array<{ fetchedAt: string; usedPercent: number; resetsAt: string; windowMinutes?: number }>;
  expected: {
    qualityState: string;
    cycleCount: number;
    forecastState: string;
    usedPercent?: number;
    confidence?: string;
    evidenceKinds?: string[];
    sustainableRate?: number;
    projectedLower?: number;
    projectedUpper?: number;
    last24Lower?: number;
    last24Upper?: number;
    ignoredShortWindow?: boolean;
    recentFasterThanCycle?: boolean;
    cycleFasterThanRecent?: boolean;
    exhaustionBeforeReset?: boolean;
    exhaustionAtNow?: boolean;
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
        windowMinutes: reading.windowMinutes ?? 10_080,
        usedPercent: reading.usedPercent,
        remainingPercent: 100 - reading.usedPercent,
        resetsAt: new Date(reading.resetsAt),
      }));

      const quality = analyzeWeeklyQuality(readings, now);
      const forecast = predictWeeklyRunway(snapshot, quality, now);

      expect(quality.state).toBe(testCase.expected.qualityState);
      expect(new Set(quality.observations.map((observation) => observation.cycleID)).size).toBe(testCase.expected.cycleCount);
      expect(forecast.state).toBe(testCase.expected.forecastState);
      if (testCase.expected.confidence !== undefined) {
        expect(forecast.confidence).toBe(testCase.expected.confidence);
      }
      if (testCase.expected.usedPercent !== undefined) {
        expect(forecast.usedPercent).toBe(testCase.expected.usedPercent);
      }
      if (testCase.expected.evidenceKinds !== undefined) {
        expect(forecast.paceEvidence.map((evidence) => evidence.kind)).toEqual(testCase.expected.evidenceKinds);
      }
      if (testCase.expected.sustainableRate !== undefined) {
        expect(forecast.sustainableRatePerDay).toBeCloseTo(testCase.expected.sustainableRate, 9);
      }
      if (testCase.expected.projectedLower !== undefined) {
        expect(forecast.projectedRemainingBandAtReset?.lower).toBeCloseTo(testCase.expected.projectedLower, 9);
        expect(forecast.projectedRemainingBandAtReset?.upper).toBeCloseTo(testCase.expected.projectedUpper!, 9);
      }
      if (testCase.expected.last24Lower !== undefined) {
        expect(forecast.last24HourUsageBand?.lower).toBeCloseTo(testCase.expected.last24Lower, 9);
        expect(forecast.last24HourUsageBand?.upper).toBeCloseTo(testCase.expected.last24Upper!, 9);
      }
      if (testCase.expected.ignoredShortWindow) {
        expect(quality.observations.every((observation) => observation.usedPercent !== 90)).toBe(true);
      }
      if (testCase.expected.recentFasterThanCycle) {
        expect(midpoint(forecast.recentRateBandPerDay)).toBeGreaterThan(midpoint(forecast.cycleRateBandPerDay));
      }
      if (testCase.expected.cycleFasterThanRecent) {
        expect(midpoint(forecast.cycleRateBandPerDay)).toBeGreaterThan(midpoint(forecast.recentRateBandPerDay));
      }
      if (testCase.expected.exhaustionBeforeReset) {
        expect(forecast.estimatedEmptyAtRange?.latest?.getTime()).toBeLessThan(new Date(testCase.snapshot.resetsAt).getTime());
      }
      if (testCase.expected.exhaustionAtNow) {
        expect(forecast.estimatedEmptyAtRange?.earliest.getTime()).toBe(now.getTime());
        expect(forecast.estimatedEmptyAtRange?.latest?.getTime()).toBe(now.getTime());
      }
    });
  }
});

function midpoint(band: { lower: number; upper: number } | null): number {
  return band ? (band.lower + band.upper) / 2 : Number.NaN;
}
