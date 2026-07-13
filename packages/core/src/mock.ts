import type { AgentQuotaSnapshot, WeeklyQuotaReading } from "./model";

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

export type WeeklyMockKind = "enough" | "watch" | "mayRunOut" | "calibrating" | "unavailable" | "exhausted";

export function createMockWeeklyScenario(
  kind: WeeklyMockKind,
  now = new Date(),
): { snapshot: AgentQuotaSnapshot; readings: WeeklyQuotaReading[] } {
  if (kind === "unavailable") {
    return {
      snapshot: { provider: "mock", sourceStatus: "error", fetchedAt: now, errorMessage: "Mock source failure." },
      readings: [],
    };
  }

  const settings = {
    enough: { used: 35, remaining: 65, resetDays: 4, values: [25, 30, 35], spacingHours: 24 },
    watch: { used: 70, remaining: 30, resetDays: 3, values: [60, 65, 70], spacingHours: 12 },
    mayRunOut: { used: 80, remaining: 20, resetDays: 3, values: [50, 65, 80], spacingHours: 24 },
    calibrating: { used: 1, remaining: 99, resetDays: 6, values: [1, 1, 1, 1, 1], spacingHours: 2 },
    exhausted: { used: 100, remaining: 0, resetDays: 2, values: [100], spacingHours: 1 },
  }[kind];
  const resetsAt = new Date(now.getTime() + settings.resetDays * 86_400_000);
  const snapshot: AgentQuotaSnapshot = {
    provider: "mock",
    sourceStatus: "ok",
    fetchedAt: now,
    weeklyWindow: {
      label: "weekly",
      windowMinutes: 10_080,
      usedPercent: settings.used,
      remainingPercent: settings.remaining,
      resetsAt,
    },
  };
  const readings = settings.values.map((usedPercent, index) => ({
    provider: "mock",
    sourceStatus: "ok" as const,
    fetchedAt: new Date(now.getTime() - (settings.values.length - 1 - index) * settings.spacingHours * 3_600_000),
    windowMinutes: 10_080,
    usedPercent,
    remainingPercent: 100 - usedPercent,
    resetsAt,
  }));
  return { snapshot, readings };
}
