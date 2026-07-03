import { describe, expect, it } from "vitest";
import { createMockSnapshot, predictCapsuleState } from "../src";

const now = new Date("2026-07-01T12:00:00+08:00");

describe("predictCapsuleState", () => {
  it("marks a healthy burn rate as safe", () => {
    const prediction = predictCapsuleState(createMockSnapshot("safe", now), { now });

    expect(prediction.level).toBe("safe");
    expect(prediction.canReachReset).toBe(true);
    expect(prediction.quotaUsedPercent).toBe(20);
    expect(prediction.projectedRemainingAtReset).toBeGreaterThan(10);
  });

  it("marks an unused short window as safe", () => {
    const prediction = predictCapsuleState(
      {
        provider: "codex",
        sourceStatus: "ok",
        fetchedAt: now,
        shortWindow: {
          label: "5h",
          windowMinutes: 300,
          usedPercent: 0,
          remainingPercent: 100,
          resetsAt: new Date(now.getTime() + 120 * 60_000),
        },
        weeklyWindow: {
          label: "weekly",
          windowMinutes: 10080,
          usedPercent: 0,
          remainingPercent: 100,
          resetsAt: new Date(now.getTime() + 5_040 * 60_000),
        },
      },
      { now },
    );

    expect(prediction.level).toBe("safe");
    expect(prediction.canReachReset).toBe(true);
    expect(prediction.quotaUsedPercent).toBe(0);
    expect(prediction.projectedRemainingAtReset).toBe(100);
  });

  it("marks low projected reset buffer as watch", () => {
    const prediction = predictCapsuleState(createMockSnapshot("watch", now), { now });

    expect(prediction.level).toBe("watch");
    expect(prediction.canReachReset).toBe(true);
  });

  it("marks projected pre-reset exhaustion as danger", () => {
    const prediction = predictCapsuleState(createMockSnapshot("danger", now), { now });

    expect(prediction.level).toBe("danger");
    expect(prediction.canReachReset).toBe(false);
    expect(prediction.estimatedEmptyAt).toBeInstanceOf(Date);
  });

  it("does not pretend source failures are safe", () => {
    const prediction = predictCapsuleState(createMockSnapshot("error", now), { now });

    expect(prediction.level).toBe("unknown");
    expect(prediction.canReachReset).toBeNull();
  });

  it("marks an exhausted short window as danger instead of unknown", () => {
    const prediction = predictCapsuleState(
      {
        provider: "codex",
        sourceStatus: "ok",
        fetchedAt: now,
        shortWindow: {
          label: "5h",
          windowMinutes: 300,
          usedPercent: 100,
          remainingPercent: 0,
          resetsAt: new Date(now.getTime() + 90 * 60_000),
        },
      },
      { now },
    );

    expect(prediction.level).toBe("danger");
    expect(prediction.canReachReset).toBe(false);
    expect(prediction.quotaUsedPercent).toBe(100);
  });

  it("marks an exhausted weekly window as danger even when the short window looks safe", () => {
    const prediction = predictCapsuleState(
      {
        provider: "codex",
        sourceStatus: "ok",
        fetchedAt: now,
        shortWindow: {
          label: "5h",
          windowMinutes: 300,
          usedPercent: 10,
          remainingPercent: 90,
          resetsAt: new Date(now.getTime() + 180 * 60_000),
        },
        weeklyWindow: {
          label: "weekly",
          windowMinutes: 10080,
          usedPercent: 100,
          remainingPercent: 0,
          resetsAt: new Date(now.getTime() + 24 * 60 * 60_000),
        },
      },
      { now },
    );

    expect(prediction.level).toBe("danger");
    expect(prediction.detail).toContain("weekly");
  });

  it("keeps a non-exhausted weekly-only snapshot unknown because the short window is missing", () => {
    const prediction = predictCapsuleState(
      {
        provider: "codex",
        sourceStatus: "ok",
        fetchedAt: now,
        weeklyWindow: {
          label: "weekly",
          windowMinutes: 10080,
          usedPercent: 40,
          remainingPercent: 60,
          resetsAt: new Date(now.getTime() + 24 * 60 * 60_000),
        },
      },
      { now },
    );

    expect(prediction.level).toBe("unknown");
    expect(prediction.headline).toContain("缺少短窗口");
  });

  it("keeps expired reset data unknown even when stale usage is exhausted", () => {
    const prediction = predictCapsuleState(
      {
        provider: "codex",
        sourceStatus: "ok",
        fetchedAt: now,
        shortWindow: {
          label: "5h",
          windowMinutes: 300,
          usedPercent: 100,
          remainingPercent: 0,
          resetsAt: new Date(now.getTime() - 60_000),
        },
      },
      { now },
    );

    expect(prediction.level).toBe("unknown");
    expect(prediction.headline).toContain("刷新时间已过期");
  });
});
