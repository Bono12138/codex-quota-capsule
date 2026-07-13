import { describe, expect, it } from "vitest";
import { createSnapshotRecord, InMemorySnapshotStore, type AgentQuotaSnapshot } from "../src";

const now = new Date("2026-07-13T00:00:00Z");

function weeklySnapshot(provider = "mock"): AgentQuotaSnapshot {
  return {
    provider,
    sourceStatus: "ok",
    fetchedAt: now,
    weeklyWindow: {
      label: "weekly",
      windowMinutes: 10_080,
      usedPercent: 35,
      remainingPercent: 65,
      resetsAt: new Date("2026-07-17T00:00:00Z"),
    },
  };
}

describe("weekly snapshot records", () => {
  it("captures only raw weekly fields and no legacy derivations", () => {
    const record = createSnapshotRecord(weeklySnapshot(), { capturedAt: now, appVersion: "0.2.0-test" });

    expect(record.windowType).toBe("weekly");
    expect(record.windowMinutes).toBe(10_080);
    expect(record.usedPercent).toBe(35);
    expect(record.remainingPercent).toBe(65);
    expect(record).not.toHaveProperty("burnRate");
    expect(record).not.toHaveProperty("projectedRemainingAtReset");
    expect(record).not.toHaveProperty("estimatedEmptyAt");
    expect(record).not.toHaveProperty("prompt");
    expect(record).not.toHaveProperty("authToken");
  });

  it("stores records in capture order and filters by provider", () => {
    const store = new InMemorySnapshotStore();
    const first = createSnapshotRecord(weeklySnapshot(), { capturedAt: now, appVersion: "0.2.0-test" });
    const second = createSnapshotRecord(weeklySnapshot("other"), {
      capturedAt: new Date(now.getTime() + 60_000),
      appVersion: "0.2.0-test",
    });

    store.add(first);
    store.add(second);

    expect(store.list().map((record) => record.provider)).toEqual(["mock", "other"]);
    expect(store.list({ provider: "mock" })).toEqual([first]);
  });
});
