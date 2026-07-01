import { describe, expect, it } from "vitest";
import { createMockSnapshot, createSnapshotRecord, InMemorySnapshotStore, predictCapsuleState } from "../src";

const now = new Date("2026-07-01T12:00:00+08:00");

describe("snapshot records", () => {
  it("captures quota and prediction fields without prompt or session content", () => {
    const snapshot = createMockSnapshot("danger", now);
    const prediction = predictCapsuleState(snapshot, { now });

    const record = createSnapshotRecord(snapshot, prediction, {
      capturedAt: now,
      appVersion: "0.0.0-test",
    });

    expect(record.provider).toBe("mock");
    expect(record.windowType).toBe("5h");
    expect(record.usedPercent).toBe(75);
    expect(record.remainingPercent).toBe(25);
    expect(record.state).toBe("danger");
    expect(record.estimatedEmptyAt).toBeInstanceOf(Date);
    expect(record.projectedRemainingAtReset).toBe(0);
    expect(record).not.toHaveProperty("prompt");
    expect(record).not.toHaveProperty("session");
    expect(record).not.toHaveProperty("authToken");
  });

  it("stores snapshots in capture order and filters by provider", () => {
    const store = new InMemorySnapshotStore();
    const safe = createSnapshotRecord(
      createMockSnapshot("safe", now),
      predictCapsuleState(createMockSnapshot("safe", now), { now }),
      { capturedAt: now, appVersion: "0.0.0-test" },
    );
    const error = createSnapshotRecord(
      { provider: "other", sourceStatus: "error", fetchedAt: now, errorMessage: "offline" },
      {
        level: "unknown",
        canReachReset: null,
        elapsedPercent: null,
        quotaUsedPercent: null,
        projectedRemainingAtReset: null,
        estimatedEmptyAt: null,
        headline: "未知",
        detail: "offline",
      },
      { capturedAt: new Date(now.getTime() + 60_000), appVersion: "0.0.0-test" },
    );

    store.add(safe);
    store.add(error);

    expect(store.list().map((record) => record.provider)).toEqual(["mock", "other"]);
    expect(store.list({ provider: "mock" })).toEqual([safe]);
  });
});
