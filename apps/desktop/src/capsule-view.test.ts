import { describe, expect, it } from "vitest";
import type { WeeklyRunwayForecast } from "@quota-capsule/core";
import { createCapsuleDisplayModel } from "./capsule-view";

function forecast(overrides: Partial<WeeklyRunwayForecast> = {}): WeeklyRunwayForecast {
  return {
    state: "enough",
    confidence: "medium",
    usedPercent: 28,
    remainingPercent: 72,
    elapsedPercent: 42,
    daysUntilReset: 4,
    sustainableRatePerDay: 12,
    recentRateBandPerDay: { lower: 6, upper: 8 },
    cycleRateBandPerDay: { lower: 5, upper: 8 },
    last24HourUsageBand: { lower: 4, upper: 6 },
    projectedRemainingBandAtReset: { lower: 16, upper: 23 },
    estimatedEmptyAtRange: null,
    next24HourBudget: 12,
    currentCycleTrend: [],
    paceEvidence: [
      { kind: "cycle", bandPerDay: { lower: 5, upper: 8 }, reliability: 0.4, transitionCount: 0, coverageHours: 48 },
      { kind: "recent", bandPerDay: { lower: 6, upper: 8 }, reliability: 0.6, transitionCount: 2, coverageHours: 24 },
      { kind: "activity", bandPerDay: { lower: 5, upper: 9 }, reliability: 0.5, transitionCount: 2, coverageHours: 30 },
    ],
    confidenceReason: "transitions:2",
    ...overrides,
  };
}

describe("createCapsuleDisplayModel", () => {
  it("renders the same Weekly Only hierarchy as the native app", () => {
    const model = createCapsuleDisplayModel(forecast());

    expect(model.statusLabel).toBe("够用");
    expect(model.defaultText).toContain("重置时预计剩 16%–23%");
    expect(model.detailMetrics.map((metric) => metric.label)).toEqual([
      "本周时间",
      "本周已用",
      "未来 24 小时建议",
      "最近 24 小时",
    ]);
    expect(model.detailMetrics.map((metric) => metric.value)).toEqual(["42%", "28%", "≤12%", "4–6%"]);
    expect(model.confidenceText).toContain("已观察到 2 次实际增长");
    expect(JSON.stringify(model)).not.toContain("5 小时");
  });

  it("shows a useful early estimate without a six-hour waiting room", () => {
    const model = createCapsuleDisplayModel(forecast({
      state: "earlyEstimate",
      confidence: "low",
      recentRateBandPerDay: null,
      last24HourUsageBand: null,
      projectedRemainingBandAtReset: { lower: -40, upper: -20 },
      paceEvidence: [{ kind: "cycle", bandPerDay: { lower: 34, upper: 38 }, reliability: 0.2, transitionCount: 0, coverageHours: 6 }],
      confidenceReason: "cycle-only",
    }));

    expect(model.statusLabel).toBe("初步估算");
    expect(model.defaultText).toBe("初步判断：按本周平均速度可能不够");
    expect(model.confidenceText).toBe("初步判断：仅依据当前周期平均速度");
    expect(JSON.stringify(model)).not.toContain("6 小时");
  });

  it("explains a first zero reading without inventing a pace warning", () => {
    const model = createCapsuleDisplayModel(forecast({
      state: "earlyEstimate",
      confidence: "low",
      usedPercent: 0,
      remainingPercent: 100,
      projectedRemainingBandAtReset: null,
      paceEvidence: [],
      confidenceReason: "no-consumption-observed",
    }));

    expect(model.defaultText).toBe("尚未观察到消耗；可先按未来 24 小时建议使用");
    expect(model.confidenceText).toBe("开始使用后会根据实际增长更新判断");
    expect(model.defaultText).not.toContain("偏快");
  });

  it("rounds the next-24-hour budget down", () => {
    const model = createCapsuleDisplayModel(forecast({ next24HourBudget: 13.9 }));
    expect(model.detailMetrics[2].value).toBe("≤13%");
  });

  it("uses reset language for exhaustion and runway risk", () => {
    expect(createCapsuleDisplayModel(forecast({ state: "exhausted" })).defaultText)
      .toBe("本周额度已用尽，重置后会自动恢复");
    expect(createCapsuleDisplayModel(forecast({ state: "mayRunOut" })).defaultText)
      .toBe("照最近速度，本周额度可能在重置前用完");
  });

  it("sanitizes non-finite and negative display values", () => {
    const model = createCapsuleDisplayModel(forecast({
      usedPercent: Number.NaN,
      remainingPercent: Number.POSITIVE_INFINITY,
      elapsedPercent: -3,
      last24HourUsageBand: { lower: Number.NEGATIVE_INFINITY, upper: Number.NaN },
      projectedRemainingBandAtReset: { lower: Number.NEGATIVE_INFINITY, upper: Number.POSITIVE_INFINITY },
      next24HourBudget: -5,
    }));
    const rendered = JSON.stringify(model).toLowerCase();

    expect(rendered).not.toContain("nan");
    expect(rendered).not.toContain("infinity");
    expect(rendered).not.toContain("-5");
  });
});
