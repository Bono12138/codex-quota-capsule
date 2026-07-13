import type { AgentQuotaSnapshot, CapsulePrediction, PredictionOptions, QuotaWindow } from "./model";

const DEFAULT_WATCH_REMAINING_THRESHOLD = 10;
const DEFAULT_JUST_RESET_MINUTES = 3;
const REPORTING_PRECISION_UPPER_BOUND = 1;
const CLOCK_SKEW_TOLERANCE_MINUTES = 2 / 60;

export function predictCapsuleState(
  snapshot: AgentQuotaSnapshot,
  options: PredictionOptions,
): CapsulePrediction {
  if (snapshot.sourceStatus === "stale") {
    if (!snapshot.shortWindow || !isValidWindow(snapshot.shortWindow)) {
      return unknownPrediction("数据已过期，等待恢复", "Showing the last successful reading; it cannot determine current risk.");
    }
    const frozen = predictWindow(snapshot.shortWindow, { ...options, now: snapshot.fetchedAt });
    return {
      level: "unknown",
      canReachReset: null,
      elapsedPercent: frozen.elapsedPercent,
      quotaUsedPercent: frozen.quotaUsedPercent,
      projectedRemainingAtReset: null,
      estimatedEmptyAt: null,
      headline: "数据已过期，等待恢复",
      detail: "正在显示最后成功读数，不能据此判断当前风险。",
    };
  }
  if (snapshot.sourceStatus !== "ok") {
    return unknownPrediction("暂时读不到额度数据", snapshot.errorMessage ?? "Source status is not ok.");
  }

  const exhaustedWindow = [snapshot.shortWindow, snapshot.weeklyWindow].find((window) =>
    isUsableExhaustedWindow(window, options.now),
  );
  if (exhaustedWindow) {
    return exhaustedPrediction(exhaustedWindow, options.now);
  }

  if (!snapshot.shortWindow) {
    return {
      ...unknownPrediction(
        "等待新的 5 小时窗口",
        "当前没有活动中的 5 小时窗口。开始使用 Codex 后会自动显示进度；如果你已经开始使用，应用会继续自动刷新。",
      ),
      isWaitingForWindow: true,
    };
  }

  return predictWindow(snapshot.shortWindow, options);
}

export function predictWindow(window: QuotaWindow, options: PredictionOptions): CapsulePrediction {
  if (!isValidWindow(window)) {
    return unknownPrediction("额度窗口数据无效", "The window duration or percentage is outside the safe range.");
  }
  const now = options.now;
  const windowStart = new Date(window.resetsAt.getTime() - window.windowMinutes * 60_000);
  const elapsedMinutes = (now.getTime() - windowStart.getTime()) / 60_000;
  const minutesUntilReset = (window.resetsAt.getTime() - now.getTime()) / 60_000;

  if (minutesUntilReset <= 0) {
    return unknownPrediction("额度刷新时间已过期", "The reset time is in the past. Refresh the source data.");
  }

  if (window.remainingPercent <= 0) {
    return exhaustedPrediction(window, now);
  }

  if (elapsedMinutes < -CLOCK_SKEW_TOLERANCE_MINUTES) {
    return unknownPrediction("本地时间可能异常", "Current time appears to be before the usage window start.");
  }

  const effectiveElapsedMinutes = Math.max(0, elapsedMinutes);

  if (window.usedPercent <= 0) {
    if (effectiveElapsedMinutes <= (options.justResetMinutes ?? DEFAULT_JUST_RESET_MINUTES)) {
      return {
        level: "unknown",
        canReachReset: null,
        elapsedPercent: clampPercent((effectiveElapsedMinutes / window.windowMinutes) * 100),
        quotaUsedPercent: 0,
        projectedRemainingAtReset: null,
        estimatedEmptyAt: null,
        headline: "当前读数低于 1%，先观察一会儿",
        detail: "Codex 的百分比读数不足以证明没有使用，暂不判断消耗速度。",
      };
    }

    const projectedUsedUpperBound =
      (REPORTING_PRECISION_UPPER_BOUND / effectiveElapsedMinutes) * window.windowMinutes;
    if (projectedUsedUpperBound >= 100) {
      return {
        level: "unknown",
        canReachReset: null,
        elapsedPercent: clampPercent((effectiveElapsedMinutes / window.windowMinutes) * 100),
        quotaUsedPercent: 0,
        projectedRemainingAtReset: null,
        estimatedEmptyAt: null,
        headline: "当前读数低于 1%，先观察一会儿",
        detail: "Codex 的百分比读数不足以证明没有使用，暂不判断消耗速度。",
      };
    }

    const conservativeRemaining = Math.max(0, Math.floor(100 - projectedUsedUpperBound));
    return {
      level: conservativeRemaining < (options.watchRemainingThreshold ?? DEFAULT_WATCH_REMAINING_THRESHOLD) ? "watch" : "safe",
      canReachReset: true,
      elapsedPercent: clampPercent((effectiveElapsedMinutes / window.windowMinutes) * 100),
      quotaUsedPercent: 0,
      projectedRemainingAtReset: conservativeRemaining,
      estimatedEmptyAt: null,
      headline: `当前读数低于 1%，保守估计够用到 ${formatTime(window.resetsAt)}`,
      detail: `按低于 1% 的上限估算，刷新时至少剩 ${conservativeRemaining}%。`,
    };
  }

  if (effectiveElapsedMinutes < (options.justResetMinutes ?? DEFAULT_JUST_RESET_MINUTES)) {
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

  const burnRatePerMinute = window.usedPercent / effectiveElapsedMinutes;
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

function exhaustedPrediction(window: QuotaWindow, now: Date): CapsulePrediction {
  const windowStart = new Date(window.resetsAt.getTime() - window.windowMinutes * 60_000);
  const elapsedMinutes = (now.getTime() - windowStart.getTime()) / 60_000;

  return {
    level: "danger",
    canReachReset: false,
    elapsedPercent: clampPercent((elapsedMinutes / window.windowMinutes) * 100),
    quotaUsedPercent: clampPercent(window.usedPercent),
    projectedRemainingAtReset: 0,
    estimatedEmptyAt: now,
    headline: "额度已经见底",
    detail: `${window.label} 窗口剩余额度为 0 或更低。`,
  };
}

function isUsableExhaustedWindow(window: Partial<QuotaWindow> | undefined, now: Date): window is QuotaWindow {
  return (
    isValidWindow(window) &&
    typeof window?.label === "string" &&
    typeof window.windowMinutes === "number" &&
    typeof window.usedPercent === "number" &&
    typeof window.remainingPercent === "number" &&
    window.resetsAt instanceof Date &&
    window.remainingPercent <= 0 &&
    window.resetsAt.getTime() > now.getTime()
  );
}

function isValidWindow(window: Partial<QuotaWindow> | undefined): window is QuotaWindow {
  return (
    typeof window?.label === "string" &&
    typeof window.windowMinutes === "number" &&
    Number.isInteger(window.windowMinutes) &&
    window.windowMinutes > 0 &&
    window.windowMinutes <= 525_600 &&
    typeof window.usedPercent === "number" &&
    Number.isFinite(window.usedPercent) &&
    window.usedPercent >= 0 &&
    window.usedPercent <= 100 &&
    typeof window.remainingPercent === "number" &&
    Number.isFinite(window.remainingPercent) &&
    window.remainingPercent >= 0 &&
    window.remainingPercent <= 100 &&
    window.resetsAt instanceof Date &&
    Number.isFinite(window.resetsAt.getTime())
  );
}
