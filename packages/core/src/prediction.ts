import type { AgentQuotaSnapshot, CapsulePrediction, PredictionOptions, QuotaWindow } from "./model";

const DEFAULT_WATCH_REMAINING_THRESHOLD = 10;
const DEFAULT_JUST_RESET_MINUTES = 3;

export function predictCapsuleState(
  snapshot: AgentQuotaSnapshot,
  options: PredictionOptions,
): CapsulePrediction {
  if (snapshot.sourceStatus !== "ok") {
    return unknownPrediction("暂时读不到额度数据", snapshot.errorMessage ?? "Source status is not ok.");
  }

  if (!snapshot.shortWindow) {
    return unknownPrediction("缺少短窗口额度数据", "The source adapter did not provide a short usage window.");
  }

  return predictWindow(snapshot.shortWindow, options);
}

export function predictWindow(window: QuotaWindow, options: PredictionOptions): CapsulePrediction {
  const now = options.now;
  const windowStart = new Date(window.resetsAt.getTime() - window.windowMinutes * 60_000);
  const elapsedMinutes = (now.getTime() - windowStart.getTime()) / 60_000;
  const minutesUntilReset = (window.resetsAt.getTime() - now.getTime()) / 60_000;

  if (minutesUntilReset <= 0) {
    return unknownPrediction("额度刷新时间已过期", "The reset time is in the past. Refresh the source data.");
  }

  if (window.remainingPercent <= 0) {
    return {
      level: "danger",
      canReachReset: false,
      elapsedPercent: clampPercent((elapsedMinutes / window.windowMinutes) * 100),
      quotaUsedPercent: clampPercent(window.usedPercent),
      projectedRemainingAtReset: 0,
      estimatedEmptyAt: now,
      headline: "额度已经见底",
      detail: "短窗口剩余额度为 0 或更低。",
    };
  }

  if (elapsedMinutes <= 0) {
    return unknownPrediction("本地时间可能异常", "Current time appears to be before the usage window start.");
  }

  if (elapsedMinutes < (options.justResetMinutes ?? DEFAULT_JUST_RESET_MINUTES)) {
    return {
      level: "unknown",
      canReachReset: null,
      elapsedPercent: clampPercent((elapsedMinutes / window.windowMinutes) * 100),
      quotaUsedPercent: clampPercent(window.usedPercent),
      projectedRemainingAtReset: null,
      estimatedEmptyAt: null,
      headline: "刚刷新，先观察一会儿",
      detail: "窗口刚开始，当前消耗速度还不稳定。",
    };
  }

  if (window.usedPercent <= 0) {
    return {
      level: "safe",
      canReachReset: true,
      elapsedPercent: clampPercent((elapsedMinutes / window.windowMinutes) * 100),
      quotaUsedPercent: 0,
      projectedRemainingAtReset: 100,
      estimatedEmptyAt: null,
      headline: `还没开始消耗，能撑到 ${formatTime(window.resetsAt)} 刷新`,
      detail: "当前窗口已用为 0。",
    };
  }

  const burnRatePerMinute = window.usedPercent / elapsedMinutes;
  const projectedUsedAtReset = window.usedPercent + burnRatePerMinute * minutesUntilReset;
  const projectedRemainingAtReset = 100 - projectedUsedAtReset;
  const canReachReset = projectedRemainingAtReset > 0;

  if (!canReachReset) {
    const estimatedEmptyAt = new Date(now.getTime() + (window.remainingPercent / burnRatePerMinute) * 60_000);
    return {
      level: "danger",
      canReachReset: false,
      elapsedPercent: clampPercent((elapsedMinutes / window.windowMinutes) * 100),
      quotaUsedPercent: clampPercent(window.usedPercent),
      projectedRemainingAtReset: clampPercent(projectedRemainingAtReset),
      estimatedEmptyAt,
      headline: `按当前速度，预计 ${formatTime(estimatedEmptyAt)} 用完`,
      detail: `撑不到 ${formatTime(window.resetsAt)} 刷新。`,
    };
  }

  const watchThreshold = options.watchRemainingThreshold ?? DEFAULT_WATCH_REMAINING_THRESHOLD;
  const level = projectedRemainingAtReset < watchThreshold ? "watch" : "safe";

  return {
    level,
    canReachReset: true,
    elapsedPercent: clampPercent((elapsedMinutes / window.windowMinutes) * 100),
    quotaUsedPercent: clampPercent(window.usedPercent),
    projectedRemainingAtReset: clampPercent(projectedRemainingAtReset),
    estimatedEmptyAt: null,
    headline:
      level === "watch"
        ? `能撑到 ${formatTime(window.resetsAt)}，但余量不多`
        : `按当前速度，够用到 ${formatTime(window.resetsAt)} 刷新`,
    detail: `刷新时预计还剩 ${Math.round(projectedRemainingAtReset)}%。`,
  };
}

export function clampPercent(value: number): number {
  if (Number.isNaN(value)) return 0;
  return Math.min(100, Math.max(0, value));
}

export function formatTime(date: Date): string {
  return new Intl.DateTimeFormat("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

function unknownPrediction(headline: string, detail: string): CapsulePrediction {
  return {
    level: "unknown",
    canReachReset: null,
    elapsedPercent: null,
    quotaUsedPercent: null,
    projectedRemainingAtReset: null,
    estimatedEmptyAt: null,
    headline,
    detail,
  };
}
