import { describe, expect, it } from "vitest";
import {
  activityEvidence,
  activitySegments,
  countUpwardTransitions,
  cycleEvidence,
  historicalEvidence,
  recentEvidence,
  type QuotaWindow,
  type WeeklyObservation,
} from "../src";

const now = new Date("2033-05-18T03:33:20Z");

describe("adaptive weekly pace evidence", () => {
  it("produces bounded cycle evidence from the first valid reading", () => {
    const evidence = cycleEvidence(window(9, 6.75), now)!;

    expect(evidence.kind).toBe("cycle");
    expect(evidence.bandPerDay.lower).toBeCloseTo(34, 9);
    expect(evidence.bandPerDay.upper).toBeCloseTo(38, 9);
    expect(evidence.reliability).toBeGreaterThanOrEqual(0.1);
    expect(evidence.reliability).toBeLessThan(0.55);
    expect(evidence.coverageHours).toBeCloseTo(6, 9);
    expect(evidence.transitionCount).toBe(0);
  });

  it("preserves an upper bound when reported use is zero", () => {
    const evidence = cycleEvidence(window(0, 6.75), now)!;
    expect(evidence.bandPerDay).toEqual({ lower: 0, upper: 2 });
  });

  it("rejects a future cycle start", () => {
    expect(cycleEvidence(window(9, 8), now)).toBeNull();
  });

  it("uses one transition in three hours without a fixed waiting gate", () => {
    const evidence = recentEvidence(observations([8, 9], 3), now)!;
    expect(evidence.kind).toBe("recent");
    expect(evidence.transitionCount).toBe(1);
    expect(evidence.coverageHours).toBeCloseTo(3, 9);
    expect(evidence.bandPerDay).toEqual({ lower: 0, upper: 16 });
  });

  it("does not turn flat polling into recent pace certainty", () => {
    expect(recentEvidence(observations([9, 9, 9], 2), now)).toBeNull();
  });

  it("decays activity pace after a burst becomes idle", () => {
    const burstEnd = new Date(now.getTime() - 12 * 3_600_000);
    const samples = [observation(new Date(burstEnd.getTime() - 2 * 3_600_000), 5), observation(burstEnd, 9)];
    const immediate = activityEvidence(samples, burstEnd)!;
    const afterIdle = activityEvidence(samples, now)!;

    expect(afterIdle.bandPerDay.upper).toBeLessThan(immediate.bandPerDay.upper);
    expect(afterIdle.bandPerDay.lower).toBeLessThan(immediate.bandPerDay.lower);
    expect(afterIdle.reliability).toBeLessThan(immediate.reliability);
  });

  it("propagates uncertainty from both quantized activity endpoints", () => {
    const samples = [
      observation(new Date(now.getTime() - 2 * 3_600_000), 5),
      observation(now, 9),
    ];
    const evidence = activityEvidence(samples, now)!;

    expect(evidence.bandPerDay.lower).toBeCloseTo(36, 9);
    expect(evidence.bandPerDay.upper).toBeCloseTo(60, 9);
  });

  it("propagates only the endpoints of a continuous activity run", () => {
    const samples = [
      observation(new Date(now.getTime() - 2 * 3_600_000), 5),
      observation(new Date(now.getTime() - 1 * 3_600_000), 6),
      observation(now, 7),
    ];
    const evidence = activityEvidence(samples, now)!;

    expect(evidence.bandPerDay.lower).toBeCloseTo(12, 9);
    expect(evidence.bandPerDay.upper).toBeCloseTo(36, 9);
  });

  it("segments active bursts, ordinary use, and idle gaps", () => {
    const samples = [
      observation(new Date(now.getTime() - 30 * 3_600_000), 5),
      observation(new Date(now.getTime() - 29 * 3_600_000), 6),
      observation(new Date(now.getTime() - 28 * 3_600_000), 7),
      observation(new Date(now.getTime() - 16 * 3_600_000), 8),
      observation(new Date(now.getTime() - 4 * 3_600_000), 8),
    ];
    const summary = activitySegments(samples, now)!;

    expect(summary.activeBurstHours).toBeCloseTo(2, 9);
    expect(summary.ordinaryUseHours).toBeCloseTo(12, 9);
    expect(summary.idleHours).toBeCloseTo(16, 9);
    expect(summary.dutyRatio).toBeCloseTo(14 / 30, 9);
    expect(summary.transitionCount).toBe(3);
  });

  it("never counts a downward correction as consumption", () => {
    const samples = observations([9, 8], 3);
    expect(countUpwardTransitions(samples)).toBe(0);
    expect(activityEvidence(samples, now)).toBeNull();
  });

  it("uses a well-observed completed cycle as a weak historical prior", () => {
    const previous = [10, 20, 30, 40].map((value, index) => observation(
      new Date(now.getTime() + (index - 4) * 24 * 3_600_000),
      value,
      0,
    ));
    const evidence = historicalEvidence([...previous, observation(now, 2, 1)], 1)!;

    expect(evidence.kind).toBe("historical");
    expect(evidence.bandPerDay.lower).toBeCloseTo(29 / 3, 9);
    expect(evidence.bandPerDay.upper).toBeCloseTo(31 / 3, 9);
    expect(evidence.reliability).toBeLessThanOrEqual(0.35);
    expect(evidence.transitionCount).toBe(3);
  });

  it("does not promote a short fragment into a historical prior", () => {
    const previous = [10, 20].map((value, index) => observation(
      new Date(now.getTime() + (index - 2) * 6 * 3_600_000),
      value,
      0,
    ));
    expect(historicalEvidence([...previous, observation(now, 2, 1)], 1)).toBeNull();
  });
});

function window(usedPercent: number, resetDays: number): QuotaWindow {
  return {
    label: "weekly",
    windowMinutes: 10_080,
    usedPercent,
    remainingPercent: 100 - usedPercent,
    resetsAt: new Date(now.getTime() + resetDays * 86_400_000),
  };
}

function observations(values: number[], spacingHours: number): WeeklyObservation[] {
  const start = now.getTime() - Math.max(0, values.length - 1) * spacingHours * 3_600_000;
  return values.map((value, index) => observation(new Date(start + index * spacingHours * 3_600_000), value));
}

function observation(fetchedAt: Date, usedPercent: number, cycleID = 0): WeeklyObservation {
  return {
    fetchedAt,
    canonicalResetAt: new Date(now.getTime() + 6 * 86_400_000),
    usedPercent,
    remainingPercent: 100 - usedPercent,
    cycleID,
    segmentID: 0,
    qualityFlags: [],
  };
}
