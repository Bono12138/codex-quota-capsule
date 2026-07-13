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
    ...overrides,
  };
}

describe("createCapsuleDisplayModel", () => {
  it("renders the same Weekly Only hierarchy as the native app", () => {
    const model = createCapsuleDisplayModel(forecast());

    expect(model.statusLabel).toBe("够用");
    expect(model.defaultText).toContain("刷新时预计剩 16%–23%");
    expect(model.detailMetrics.map((metric) => metric.label)).toEqual([
      "本周时间",
      "本周已用",
      "最近 24 小时",
      "未来 24 小时建议",
    ]);
    expect(model.detailMetrics.map((metric) => metric.value)).toEqual(["42%", "28%", "4–6%", "≤12%"]);
    expect(model.confidenceText).toBe("预测可信度：中");
    expect(JSON.stringify(model)).not.toContain("5 小时");
  });

  it("calibration does not make a runway claim", () => {
    const model = createCapsuleDisplayModel(forecast({
      state: "calibrating",
      confidence: "low",
      recentRateBandPerDay: null,
      last24HourUsageBand: null,
      projectedRemainingBandAtReset: null,
    }));

    expect(model.statusLabel).toBe("正在校准");
    expect(model.defaultText).toContain("周速度");
    expect(model.defaultText).not.toContain("预计剩");
    expect(model.confidenceText).toBe("");
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
