import type { AgentQuotaSnapshot } from "./model";

const WINDOW_MINUTES = 300;

export function createMockSnapshot(kind: "safe" | "watch" | "danger" | "just-reset" | "error", now = new Date()): AgentQuotaSnapshot {
  if (kind === "error") {
    return {
      provider: "mock",
      sourceStatus: "error",
      fetchedAt: now,
      errorMessage: "Mock source failure.",
    };
  }

  const resetsAt = new Date(now.getTime() + 120 * 60_000);
  const base = {
    provider: "mock",
    sourceStatus: "ok" as const,
    fetchedAt: now,
  };

  if (kind === "just-reset") {
    return {
      ...base,
      shortWindow: {
        label: "5h",
        windowMinutes: WINDOW_MINUTES,
        usedPercent: 1,
        remainingPercent: 99,
        resetsAt: new Date(now.getTime() + (WINDOW_MINUTES - 1) * 60_000),
      },
    };
  }

  const values = {
    safe: { usedPercent: 20, remainingPercent: 80 },
    watch: { usedPercent: 58, remainingPercent: 42 },
    danger: { usedPercent: 75, remainingPercent: 25 },
  }[kind];

  return {
    ...base,
    shortWindow: {
      label: "5h",
      windowMinutes: WINDOW_MINUTES,
      usedPercent: values.usedPercent,
      remainingPercent: values.remainingPercent,
      resetsAt,
    },
    weeklyWindow: {
      label: "weekly",
      remainingPercent: 64,
      usedPercent: 36,
    },
    resetCount: 1,
  };
}

