import { describe, expect, it } from "vitest";
import { createMockSnapshot, predictCapsuleState } from "../src";

const now = new Date("2026-07-01T12:00:00+08:00");

describe("predictCapsuleState", () => {
  it("marks a healthy burn rate as safe", () => {
    const prediction = predictCapsuleState(createMockSnapshot("safe", now), { now });

    expect(prediction.level).toBe("safe");
    expect(prediction.canReachReset).toBe(true);
    expect(prediction.projectedRemainingAtReset).toBeGreaterThan(10);
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
});

