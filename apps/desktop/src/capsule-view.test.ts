import { describe, expect, it } from "vitest";
import { createMockSnapshot, predictCapsuleState } from "@quota-capsule/core";
import { createCapsuleDisplayModel } from "./capsule-view";

const now = new Date("2026-07-01T12:00:00+08:00");

describe("createCapsuleDisplayModel", () => {
  it("labels a weekly-only live snapshot as waiting instead of unknown", () => {
    const snapshot = {
      provider: "codex",
      sourceStatus: "ok" as const,
      fetchedAt: now,
      weeklyWindow: {
        label: "weekly",
        windowMinutes: 10080,
        usedPercent: 0,
        remainingPercent: 100,
        resetsAt: new Date(now.getTime() + 7 * 24 * 60 * 60_000),
      },
    };
    const prediction = predictCapsuleState(snapshot, { now });

    const model = createCapsuleDisplayModel(snapshot, prediction);

    expect(model.statusLabel).toBe("待开始");
    expect(model.defaultText).toContain("等待新的 5 小时窗口");
    expect(model.detailMetrics.every((metric) => metric.value === "待开始")).toBe(true);
    expect(model.tone).toBe("unknown");
  });

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
