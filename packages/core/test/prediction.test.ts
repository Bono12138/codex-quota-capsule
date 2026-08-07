import { describe, expect, it } from "vitest";
import {
  analyzeWeeklyQuality,
  createMockWeeklyScenario,
  formatObservedUsage,
  formatWeeklyProjection,
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
  it("uses an earlier reset-credit expiry as the current burn horizon", () => {
    const resetsAt = new Date(now.getTime() + 7 * 86_400_000);
    const creditExpiresAt = new Date(now.getTime() + 0.75 * 86_400_000);
    const snapshot: AgentQuotaSnapshot = {
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: now,
      weeklyWindow: {
        label: "weekly",
        windowMinutes: 10_080,
        usedPercent: 0,
        remainingPercent: 100,
        resetsAt,
      },
      resetCreditBank: {
        availableCount: 1,
        credits: [{
          fingerprint: "credit-1",
          resetType: "codexRateLimits",
          status: "available",
          grantedAt: null,
          grantTimeSource: "unknown",
          expiresAt: creditExpiresAt,
          title: "Full reset",
        }],
        detailState: "complete",
        fetchedAt: now,
      },
    };
    const quality = analyzeWeeklyQuality(readings([0], resetsAt), now);
    const forecast = predictWeeklyRunway(snapshot, quality, now);

    expect(forecast.daysUntilReset).toBeCloseTo(0.75, 9);
    expect(forecast.sustainableRatePerDay).toBeCloseTo(100 / 0.75, 9);
    expect(forecast.next24HourBudget).toBe(100);
    expect(forecast.burnHorizonAt).toEqual(creditExpiresAt);
    expect(forecast.burnHorizonSource).toBe("resetCreditExpiry");
    expect(forecast.confidenceReason).toBe("no-consumption-observed");
  });

  it("uses the real weekly start for progress and the credit deadline for its endpoint", () => {
    const resetsAt = new Date(now.getTime() + 6.9 * 86_400_000);
    const creditExpiresAt = new Date(now.getTime() + 0.75 * 86_400_000);
    const snapshot: AgentQuotaSnapshot = {
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: now,
      weeklyWindow: {
        label: "weekly",
        windowMinutes: 10_080,
        usedPercent: 2,
        remainingPercent: 98,
        resetsAt,
      },
      resetCreditBank: {
        availableCount: 1,
        credits: [{
          fingerprint: "credit-1",
          resetType: "codexRateLimits",
          status: "available",
          grantedAt: null,
          grantTimeSource: "unknown",
          expiresAt: creditExpiresAt,
          title: "Full reset",
        }],
        detailState: "complete",
        fetchedAt: now,
      },
    };
    const quality = analyzeWeeklyQuality(readings([2], resetsAt), now);
    const forecast = predictWeeklyRunway(snapshot, quality, now);

    expect(forecast.elapsedPercent).toBeCloseTo((0.1 / 0.85) * 100, 9);
  });

  it("keeps the natural reset when it is earlier and ignores unusable credits", () => {
    const resetsAt = new Date(now.getTime() + 0.5 * 86_400_000);
    const credit = (
      fingerprint: string,
      status: "available" | "redeemed",
      expiresAt: Date | null,
    ) => ({
      fingerprint,
      resetType: "codexRateLimits",
      status,
      grantedAt: null,
      grantTimeSource: "unknown" as const,
      expiresAt,
      title: "Full reset",
    });
    const snapshot: AgentQuotaSnapshot = {
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: now,
      weeklyWindow: {
        label: "weekly",
        windowMinutes: 10_080,
        usedPercent: 20,
        remainingPercent: 80,
        resetsAt,
      },
      resetCreditBank: {
        availableCount: 3,
        credits: [
          credit("later", "available", new Date(now.getTime() + 86_400_000)),
          credit("expired", "available", new Date(now.getTime() - 1)),
          credit("redeemed", "redeemed", new Date(now.getTime() + 0.25 * 86_400_000)),
          credit("undated", "available", null),
        ],
        detailState: "complete",
        fetchedAt: now,
      },
    };
    const quality = analyzeWeeklyQuality(readings([20], resetsAt), now);
    const forecast = predictWeeklyRunway(snapshot, quality, now);

    expect(forecast.daysUntilReset).toBeCloseTo(0.5, 9);
    expect(forecast.next24HourBudget).toBe(80);
    expect(forecast.burnHorizonSource).toBe("naturalReset");
  });

  it("trusts an authoritative zero available count over stale detail rows", () => {
    const resetsAt = new Date(now.getTime() + 4 * 86_400_000);
    const snapshot: AgentQuotaSnapshot = {
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: now,
      weeklyWindow: {
        label: "weekly",
        windowMinutes: 10_080,
        usedPercent: 20,
        remainingPercent: 80,
        resetsAt,
      },
      resetCreditBank: {
        availableCount: 0,
        credits: [{
          fingerprint: "stale-detail",
          resetType: "codexRateLimits",
          status: "available",
          grantedAt: null,
          grantTimeSource: "unknown",
          expiresAt: new Date(now.getTime() + 0.5 * 86_400_000),
          title: "Full reset",
        }],
        detailState: "complete",
        fetchedAt: now,
      },
    };
    const quality = analyzeWeeklyQuality(readings([20], resetsAt), now);
    const forecast = predictWeeklyRunway(snapshot, quality, now);

    expect(forecast.burnHorizonSource).toBe("naturalReset");
    expect(forecast.daysUntilReset).toBe(4);
  });

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

  it("rebases an unused sliding window after an application gap", () => {
    const start = new Date(now.getTime() - 92 * 60_000);
    const oldReset = new Date(now.getTime() + 4 * 86_400_000);
    const correctedReset = new Date(oldReset.getTime() + 14_000_000);
    const reading = (minute: number, usedPercent: number, resetsAt: Date): WeeklyQuotaReading => ({
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: new Date(start.getTime() + minute * 60_000),
      windowMinutes: 10_080,
      usedPercent,
      remainingPercent: 100 - usedPercent,
      resetsAt,
    });
    const quality = analyzeWeeklyQuality([
      reading(0, 0, oldReset),
      reading(90, 0, correctedReset),
      reading(91, 1, correctedReset),
      reading(92, 2, correctedReset),
    ], now);

    expect(quality.state).toBe("stable");
    expect(quality.observations.map((item) => item.usedPercent)).toEqual([0, 1, 2]);
    expect(quality.canonicalResetAt).toEqual(correctedReset);
    expect(new Set(quality.observations.map((item) => item.cycleID))).toEqual(new Set([0]));
  });

  it("accepts a persistent reset-time correction after confirmation", () => {
    const start = new Date(now.getTime() - 4 * 60_000);
    const oldReset = new Date(now.getTime() + 4 * 86_400_000);
    const correctedReset = new Date(oldReset.getTime() + 14_000_000);
    const reading = (minute: number, usedPercent: number, resetsAt: Date): WeeklyQuotaReading => ({
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: new Date(start.getTime() + minute * 60_000),
      windowMinutes: 10_080,
      usedPercent,
      remainingPercent: 100 - usedPercent,
      resetsAt,
    });
    const quality = analyzeWeeklyQuality([
      reading(0, 10, oldReset),
      reading(1, 10, new Date(oldReset.getTime() + 1_000)),
      reading(2, 11, correctedReset),
      reading(3, 11, new Date(correctedReset.getTime() + 1_000)),
      reading(4, 12, new Date(correctedReset.getTime() - 1_000)),
    ], now);

    expect(quality.state).toBe("stable");
    expect(quality.observations.at(-1)?.usedPercent).toBe(12);
    expect(quality.canonicalResetAt).toEqual(correctedReset);
    expect(new Set(quality.observations.map((item) => item.cycleID))).toEqual(new Set([0]));
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
    expect(forecast.observedUsage).toEqual({
      coverageSeconds: 172_800,
      increaseBand: { lower: 9, upper: 11 },
    });
  });

  it("formats raw projection scenarios and actual observation periods", () => {
    expect(formatWeeklyProjection({ lower: -22, upper: 44 }, "zh-Hans"))
      .toBe("按较快节奏可能提前用完；较慢情景重置时最多剩 44%");
    expect(formatWeeklyProjection({ lower: 12.2, upper: 18.8 }, "zh-Hans"))
      .toBe("照最近速度，重置时预计剩 12%–19%");
    expect(formatObservedUsage({
      coverageSeconds: 8 * 3_600 + 15 * 60,
      increaseBand: { lower: 16, upper: 18 },
    }, "zh-Hans")).toBe("近 8 小时 15 分钟已用约 16%–18%");
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

  it("does not let flat polling turn a low-use week into running fast", () => {
    const resetsAt = new Date(now.getTime() + 5.8 * 86_400_000);
    const sparsePoints: Array<[number, number]> = [
      [-24, 0], [-6, 1], [-4, 2], [-1, 4], [0, 4],
    ];
    const polledPoints = sparsePoints.slice();
    for (let hour = 1; hour < 18; hour += 1) polledPoints.push([hour - 24, 0]);
    for (let minute = -350; minute <= -250; minute += 10) polledPoints.push([minute / 60, 1]);
    for (let minute = -230; minute <= -70; minute += 10) polledPoints.push([minute / 60, 2]);
    for (let minute = -50; minute <= -10; minute += 10) polledPoints.push([minute / 60, 4]);
    const makeReadings = (points: Array<[number, number]>): WeeklyQuotaReading[] => points
      .slice()
      .sort((left, right) => left[0] - right[0])
      .map(([hours, usedPercent]) => ({
        provider: "codex",
        sourceStatus: "ok",
        fetchedAt: new Date(now.getTime() + hours * 3_600_000),
        windowMinutes: 10_080,
        usedPercent,
        remainingPercent: 100 - usedPercent,
        resetsAt,
      }));
    const snapshot: AgentQuotaSnapshot = {
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: now,
      weeklyWindow: { label: "weekly", windowMinutes: 10_080, usedPercent: 4, remainingPercent: 96, resetsAt },
    };
    const sparse = predictWeeklyRunway(snapshot, analyzeWeeklyQuality(makeReadings(sparsePoints), now), now);
    const polled = predictWeeklyRunway(snapshot, analyzeWeeklyQuality(makeReadings(polledPoints), now), now);

    expect(sparse.state).toBe("enough");
    expect(polled.state).toBe("enough");
    expect(polled.projectedRemainingBandAtReset!.lower).toBeGreaterThan(0);
  });

  it("does not extrapolate a seven-hour burst across the rest of the week", () => {
    const daysRemaining = 5.78;
    const resetsAt = new Date(now.getTime() + daysRemaining * 86_400_000);
    const points: Array<[number, number]> = [
      [-7, 0], [-6.75, 1], [-4.7, 2], [-1.55, 4], [-0.7, 5], [0, 6],
    ];
    const liveReadings: WeeklyQuotaReading[] = points.map(([hours, usedPercent]) => ({
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: new Date(now.getTime() + hours * 3_600_000),
      windowMinutes: 10_080,
      usedPercent,
      remainingPercent: 100 - usedPercent,
      resetsAt,
    }));
    const snapshot: AgentQuotaSnapshot = {
      provider: "codex",
      sourceStatus: "ok",
      fetchedAt: now,
      weeklyWindow: { label: "weekly", windowMinutes: 10_080, usedPercent: 6, remainingPercent: 94, resetsAt },
    };

    const forecast = predictWeeklyRunway(snapshot, analyzeWeeklyQuality(liveReadings, now), now);
    const projected = forecast.projectedRemainingBandAtReset!;

    expect(forecast.state).toBe("enough");
    expect(projected.lower).toBeGreaterThan(35);
    expect(projected.upper - projected.lower).toBeLessThan(25);
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
