import { describe, expect, it } from "vitest";
import {
  analyzeWeeklyQuality,
  createMockWeeklyScenario,
  predictWeeklyRunway,
  type AgentQuotaSnapshot,
  type WeeklyQuotaReading,
} from "../src";

const now = new Date("2026-07-01T12:00:00+08:00");

function forecastFor(kind: Parameters<typeof createMockWeeklyScenario>[0]) {
  const scenario = createMockWeeklyScenario(kind, now);
  const quality = analyzeWeeklyQuality(scenario.readings, now);
  return predictWeeklyRunway(scenario.snapshot, quality, now);
}

function readings(values: number[], resetsAt: Date): WeeklyQuotaReading[] {
  return values.map((usedPercent, index) => ({
    provider: "codex",
    sourceStatus: "ok",
    fetchedAt: new Date(now.getTime() - (values.length - 1 - index) * 12 * 3_600_000),
    windowMinutes: 10_080,
    usedPercent,
    remainingPercent: 100 - usedPercent,
    resetsAt,
  }));
}

describe("Weekly Only runway", () => {
  it("keeps every public mock scenario in its intended user state", () => {
    expect(forecastFor("enough").state).toBe("enough");
    expect(forecastFor("watch").state).toBe("watch");
    expect(forecastFor("mayRunOut").state).toBe("mayRunOut");
    expect(forecastFor("earlyEstimate").state).toBe("earlyEstimate");
    expect(forecastFor("calibrating").state).toBe("calibrating");
    expect(forecastFor("unavailable").state).toBe("unavailable");
    expect(forecastFor("exhausted").state).toBe("exhausted");
  });

  it("requires three mutually consistent readings after an alternating stream", () => {
    const start = new Date(now.getTime() - 7 * 60_000);
    const resetA = new Date(now.getTime() + 4 * 86_400_000);
    const resetB = new Date(resetA.getTime() + 70_000);
    const reading = (minute: number, usedPercent: number, resetsAt: Date): WeeklyQuotaReading => ({
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: new Date(start.getTime() + minute * 60_000),
      windowMinutes: 10_080,
      usedPercent,
      remainingPercent: 100 - usedPercent,
      resetsAt,
    });
    const alternating = [
      reading(0, 1, resetA),
      reading(1, 5, resetB),
      reading(2, 1, resetA),
      reading(3, 5, resetB),
      reading(4, 1, resetA),
    ];
    const twoConsistent = [...alternating, reading(5, 5, resetB), reading(6, 5, resetB)];
    const recovered = [...twoConsistent, reading(7, 5, resetB)];

    const blocked = analyzeWeeklyQuality(twoConsistent, now);
    const stable = analyzeWeeklyQuality(recovered, now);

    expect(blocked.state).toBe("unstable");
    expect(blocked.flags).toContain("alternatingStream");
    expect(stable.state).toBe("stable");
    expect(stable.flags).toContain("alternatingStream");
    expect(new Set(stable.observations.map((item) => item.usedPercent))).toEqual(new Set([5]));
  });

  it("never promotes stale readings into a runway judgment", () => {
    const resetsAt = new Date(now.getTime() + 4 * 86_400_000);
    const staleReadings = readings([20, 25, 30], resetsAt).map((reading) => ({
      ...reading,
      fetchedAt: new Date(reading.fetchedAt.getTime() - 10 * 60_000),
    }));
    const snapshot: AgentQuotaSnapshot = {
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: now,
      weeklyWindow: { label: "weekly", windowMinutes: 10_080, usedPercent: 30, remainingPercent: 70, resetsAt },
    };
    const quality = analyzeWeeklyQuality(staleReadings, now);
    const forecast = predictWeeklyRunway(snapshot, quality, now);

    expect(quality.state).toBe("stale");
    expect(forecast.state).toBe("unavailable");
    expect(forecast.projectedRemainingBandAtReset).toBeNull();
  });

  it("does not forecast from an unconfirmed reset candidate", () => {
    const acceptedReset = new Date(now.getTime() + 4 * 86_400_000);
    const candidateReset = new Date(now.getTime() + 6 * 86_400_000);
    const history: WeeklyQuotaReading[] = [
      ...readings([30], acceptedReset).map((reading) => ({ ...reading, fetchedAt: new Date(now.getTime() - 60_000) })),
      {
        provider: "codex",
        sourceStatus: "ok",
        fetchedAt: now,
        windowMinutes: 10_080,
        usedPercent: 2,
        remainingPercent: 98,
        resetsAt: candidateReset,
      },
    ];
    const quality = analyzeWeeklyQuality(history, now);
    const forecast = predictWeeklyRunway({
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: now,
      weeklyWindow: {
        label: "weekly",
        windowMinutes: 10_080,
        usedPercent: 2,
        remainingPercent: 98,
        resetsAt: candidateReset,
      },
    }, quality, now);

    expect(quality.state).toBe("calibrating");
    expect(forecast.state).toBe("calibrating");
    expect(forecast.usedPercent).toBe(30);
    expect(forecast.projectedRemainingBandAtReset).toBeNull();
  });

  it("uses the full remaining allowance without a hidden reserve", () => {
    const forecast = forecastFor("enough");
    expect(forecast.sustainableRatePerDay).toBeCloseTo(65 / 4, 9);
    expect(forecast.next24HourBudget).toBeCloseTo(65 / 4, 9);
    expect(forecast.next24HourBudget).toBeLessThan(forecast.remainingPercent!);
    expect(forecast.last24HourUsageBand).toEqual({ lower: 4, upper: 6 });
    expect(forecast.currentCycleTrend).toHaveLength(3);
  });

  it("does not warn that a zero reading just after reset is running fast", () => {
    const daysRemaining = 7 - 10 / 1_440;
    const resetsAt = new Date(now.getTime() + daysRemaining * 86_400_000);
    const snapshot: AgentQuotaSnapshot = {
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: now,
      weeklyWindow: { label: "weekly", windowMinutes: 10_080, usedPercent: 0, remainingPercent: 100, resetsAt },
    };
    const quality = analyzeWeeklyQuality(readings([0], resetsAt), now);
    const forecast = predictWeeklyRunway(snapshot, quality, now);

    expect(forecast.state).toBe("earlyEstimate");
    expect(forecast.paceEvidence).toEqual([]);
    expect(forecast.projectedRemainingBandAtReset).toBeNull();
    expect(forecast.confidenceReason).toBe("no-consumption-observed");
  });

  it("exposes the same exhaustion interval contract as the native engine", () => {
    const forecast = forecastFor("mayRunOut");

    expect(forecast.estimatedEmptyAtRange?.earliest).toBeInstanceOf(Date);
    expect(forecast.estimatedEmptyAtRange?.latest).toBeInstanceOf(Date);
    expect(forecast.estimatedEmptyAtRange!.earliest.getTime()).toBeLessThan(forecast.estimatedEmptyAtRange!.latest!.getTime());
  });

  it("falls back to current-cycle evidence when history disagrees with the live reading", () => {
    const scenario = createMockWeeklyScenario("enough", now);
    const quality = analyzeWeeklyQuality(scenario.readings, now);
    const mismatched: AgentQuotaSnapshot = {
      ...scenario.snapshot,
      weeklyWindow: { ...scenario.snapshot.weeklyWindow!, usedPercent: 50, remainingPercent: 50 },
    };

    const forecast = predictWeeklyRunway(mismatched, quality, now);
    expect(forecast.state).toBe("earlyEstimate");
    expect(forecast.paceEvidence.map((evidence) => evidence.kind)).toEqual(["cycle"]);
  });

  it("does not improve the judgment when both usage and pace increase", () => {
    const resetsAt = new Date(now.getTime() + 3 * 86_400_000);
    const lowerReadings = readings([20, 25, 30], resetsAt);
    const higherReadings = readings([30, 45, 60], resetsAt);
    const lower = predictWeeklyRunway(
      { provider: "codex", sourceStatus: "ok", fetchedAt: now, weeklyWindow: { label: "weekly", windowMinutes: 10_080, usedPercent: 30, remainingPercent: 70, resetsAt } },
      analyzeWeeklyQuality(lowerReadings, now),
      now,
    );
    const higher = predictWeeklyRunway(
      { provider: "codex", sourceStatus: "ok", fetchedAt: now, weeklyWindow: { label: "weekly", windowMinutes: 10_080, usedPercent: 60, remainingPercent: 40, resetsAt } },
      analyzeWeeklyQuality(higherReadings, now),
      now,
    );
    const severity = { enough: 0, watch: 1, mayRunOut: 2, exhausted: 3, earlyEstimate: -1, calibrating: -1, unavailable: -1 };

    expect(severity[higher.state]).toBeGreaterThanOrEqual(severity[lower.state]);
    expect(higher.next24HourBudget!).toBeLessThan(lower.next24HourBudget!);
  });

  it("rejects non-finite weekly data without leaking NaN or Infinity", () => {
    const snapshot: AgentQuotaSnapshot = {
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: now,
      weeklyWindow: {
        label: "weekly",
        windowMinutes: 10_080,
        usedPercent: Number.NaN,
        remainingPercent: Number.POSITIVE_INFINITY,
        resetsAt: new Date(now.getTime() + 4 * 86_400_000),
      },
    };
    const forecast = predictWeeklyRunway(snapshot, { state: "unavailable", observations: [], canonicalResetAt: null, flags: [] }, now);

    expect(forecast.state).toBe("unavailable");
    expect(JSON.stringify(forecast)).not.toMatch(/NaN|Infinity/);
  });
});
