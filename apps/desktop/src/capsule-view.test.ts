import { describe, expect, it } from "vitest";
import { createMockSnapshot, predictCapsuleState } from "@quota-capsule/core";
import { createCapsuleDisplayModel } from "./capsule-view";

const now = new Date("2026-07-01T12:00:00+08:00");

describe("createCapsuleDisplayModel", () => {
  it("keeps the default capsule compact while exposing detail metrics", () => {
    const snapshot = createMockSnapshot("safe", now);
    const prediction = predictCapsuleState(snapshot, { now });

    const model = createCapsuleDisplayModel(snapshot, prediction);

    expect(model.statusLabel).toBe("安全");
    expect(model.defaultText).toContain("够用到");
    expect(model.defaultText.length).toBeLessThanOrEqual(24);
    expect(model.detailMetrics.map((metric) => metric.label)).toEqual([
      "时间进度",
      "额度已用",
      "当前速度",
      "刷新余量",
    ]);
    expect(model.historyCta).toBe("查看历史");
  });

  it("surfaces unknown data without pretending it is safe", () => {
    const snapshot = createMockSnapshot("error", now);
    const prediction = predictCapsuleState(snapshot, { now });

    const model = createCapsuleDisplayModel(snapshot, prediction);

    expect(model.statusLabel).toBe("未知");
    expect(model.defaultText).toBe("暂时读不到额度");
    expect(model.tone).toBe("unknown");
  });
});
