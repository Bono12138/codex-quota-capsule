import type {
  AgentQuotaSnapshot,
  CapsulePrediction,
  PaceBand,
  PercentageBand,
  PredictionOptions,
  QuotaWindow,
  WeeklyObservation,
  WeeklyQualityFlag,
  WeeklyQualityResult,
  WeeklyQuotaReading,
  WeeklyRunwayForecast,
} from "./model";

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

const WEEKLY_MINUTES = 10_080;
const RESET_CLUSTER_TOLERANCE_MS = 5 * 60_000;
const FRESHNESS_THRESHOLD_MS = 180_000;
const CONFIRMATION_SPAN_MS = 120_000;
const MINIMUM_COVERAGE_MS = 6 * 60 * 60_000;
const RECENT_HORIZON_MS = 24 * 60 * 60_000;
const RESERVE_PERCENT = 5;

export function analyzeWeeklyQuality(readings: WeeklyQuotaReading[], now = new Date()): WeeklyQualityResult {
  const ordered = readings
    .filter((reading) => isUsableWeeklyReading(reading, now))
    .slice()
    .sort((left, right) => left.fetchedAt.getTime() - right.fetchedAt.getTime() || left.resetsAt.getTime() - right.resetsAt.getTime());
  const latest = ordered.at(-1);
  if (!latest) return { state: "unavailable", observations: [], canonicalResetAt: null, flags: [] };
  if (now.getTime() - latest.fetchedAt.getTime() > FRESHNESS_THRESHOLD_MS) {
    return {
      state: "stale",
      observations: [makeObservation(latest, latest.resetsAt, 0, 0, ["staleSource"])],
      canonicalResetAt: latest.resetsAt,
      flags: ["staleSource"],
    };
  }
  if (hasAlternatingTail(ordered)) {
    const first = ordered[ordered.length - 5];
    return {
      state: "unstable",
      observations: [makeObservation(first, first.resetsAt, 0, 0)],
      canonicalResetAt: first.resetsAt,
      flags: ["alternatingStream"],
    };
  }

  let accepted: WeeklyObservation[] = [];
  const flags = new Set<WeeklyQualityFlag>();
  let activeResetSamples: Date[] = [];
  let activeReset: Date | null = null;
  let cycleID = 0;
  let segmentID = 0;
  let pendingCycle: WeeklyQuotaReading[] = [];
  let pendingCorrection: WeeklyQuotaReading[] = [];
  let calibrating = false;

  for (const reading of ordered) {
    const lastAccepted = accepted.at(-1);
    if (!activeReset || !lastAccepted) {
      activeResetSamples = [reading.resetsAt];
      activeReset = reading.resetsAt;
      accepted.push(makeObservation(reading, activeReset, cycleID, segmentID));
      continue;
    }

    const sameCluster = Math.abs(reading.resetsAt.getTime() - activeReset.getTime()) <= RESET_CLUSTER_TOLERANCE_MS;
    if (!sameCluster) {
      const resetMovedForward = reading.resetsAt.getTime() - activeReset.getTime() >= 6 * 60 * 60_000;
      const usageDropped = lastAccepted.usedPercent - reading.usedPercent >= 2;
      if (!resetMovedForward && !usageDropped) {
        flags.add("resetCandidate");
        calibrating = true;
        continue;
      }

      if (!pendingCycle.length || Math.abs(reading.resetsAt.getTime() - pendingCycle[0].resetsAt.getTime()) <= RESET_CLUSTER_TOLERANCE_MS) {
        pendingCycle.push(reading);
      } else {
        pendingCycle = [reading];
      }
      flags.add("resetCandidate");
      if (isConfirmed(pendingCycle)) {
        cycleID += 1;
        segmentID += 1;
        activeResetSamples = pendingCycle.map((item) => item.resetsAt);
        activeReset = medianDate(activeResetSamples);
        if (activeResetSamples.some((date) => date.getTime() !== activeReset!.getTime())) flags.add("resetJitter");
        accepted.push(...pendingCycle.map((item) => makeObservation(item, activeReset!, cycleID, segmentID, ["resetCandidate"])));
        pendingCycle = [];
        pendingCorrection = [];
        calibrating = false;
      } else {
        calibrating = true;
      }
      continue;
    }

    pendingCycle = [];
    activeResetSamples.push(reading.resetsAt);
    activeReset = medianDate(activeResetSamples);
    if (activeResetSamples.some((date) => date.getTime() !== activeReset!.getTime())) flags.add("resetJitter");
    accepted = accepted.map((item) => item.cycleID === cycleID ? { ...item, canonicalResetAt: activeReset! } : item);

    if (reading.usedPercent < lastAccepted.usedPercent) {
      if (!pendingCorrection.length || reading.usedPercent >= pendingCorrection.at(-1)!.usedPercent) {
        pendingCorrection.push(reading);
      } else {
        pendingCorrection = [reading];
      }
      flags.add("correction");
      if (isConfirmed(pendingCorrection)) {
        segmentID += 1;
        accepted.push(...pendingCorrection.map((item) => makeObservation(item, activeReset!, cycleID, segmentID, ["correction"])));
        pendingCorrection = [];
        calibrating = false;
      } else {
        calibrating = true;
      }
      continue;
    }

    pendingCorrection = [];
    calibrating = false;
    accepted.push(makeObservation(reading, activeReset, cycleID, segmentID));
  }

  return {
    state: calibrating ? "calibrating" : "stable",
    observations: sampleWeeklyObservations(accepted),
    canonicalResetAt: activeReset,
    flags: [...flags],
  };
}

export function predictWeeklyRunway(
  snapshot: AgentQuotaSnapshot,
  quality: WeeklyQualityResult,
  now = new Date(),
): WeeklyRunwayForecast {
  const window = snapshot.weeklyWindow;
  if (snapshot.sourceStatus !== "ok" || !isValidWeeklyWindow(window, now)) return unavailableWeeklyForecast();

  const daysRemaining = (window.resetsAt.getTime() - now.getTime()) / 86_400_000;
  const start = window.resetsAt.getTime() - window.windowMinutes * 60_000;
  const elapsedPercent = Math.min(100, Math.max(0, ((now.getTime() - start) / (window.windowMinutes * 60_000)) * 100));
  const sustainable = Math.max(0, window.remainingPercent - RESERVE_PERCENT) / daysRemaining;
  const budget = Math.min(window.remainingPercent, sustainable);

  if (window.remainingPercent <= 0) {
    return makeWeeklyForecast("exhausted", "low", window, elapsedPercent, daysRemaining, 0, null, null, { lower: 0, upper: 0 }, 0);
  }
  if (quality.state === "stale" || quality.state === "unavailable") {
    return { ...unavailableWeeklyForecast(), usedPercent: window.usedPercent, remainingPercent: window.remainingPercent, elapsedPercent, daysUntilReset: daysRemaining };
  }
  if (quality.state !== "stable") {
    return makeWeeklyForecast("calibrating", "low", window, elapsedPercent, daysRemaining, sustainable, null, null, null, budget);
  }

  const active = activeCycleAndSegment(quality.observations);
  const latest = active.at(-1);
  if (!latest || Math.abs(latest.usedPercent - window.usedPercent) > 1.5 || Math.abs(latest.canonicalResetAt.getTime() - window.resetsAt.getTime()) > RESET_CLUSTER_TOLERANCE_MS) {
    return makeWeeklyForecast("calibrating", "low", window, elapsedPercent, daysRemaining, sustainable, null, null, null, budget);
  }
  const cycleBand = qualifiedPaceBand(active);
  const recent = active.filter((observation) => now.getTime() - observation.fetchedAt.getTime() <= RECENT_HORIZON_MS);
  const recentBand = qualifiedPaceBand(recent);
  if (!cycleBand || !recentBand) {
    return makeWeeklyForecast("calibrating", "low", window, elapsedPercent, daysRemaining, sustainable, recentBand, cycleBand, null, budget);
  }

  const pace = { lower: Math.min(cycleBand.lower, recentBand.lower), upper: Math.max(cycleBand.upper, recentBand.upper) };
  const projected = {
    lower: window.remainingPercent - pace.upper * daysRemaining,
    upper: window.remainingPercent - pace.lower * daysRemaining,
  };
  const state = projected.lower >= RESERVE_PERCENT ? "enough" : projected.upper < 0 ? "mayRunOut" : "watch";
  const coverage = active.at(-1)!.fetchedAt.getTime() - active[0].fetchedAt.getTime();
  const confidence = coverage >= RECENT_HORIZON_MS && upwardTransitionCount(active) >= 3 ? "high" : "medium";
  return makeWeeklyForecast(state, confidence, window, elapsedPercent, daysRemaining, sustainable, recentBand, cycleBand, projected, budget);
}

function isUsableWeeklyReading(reading: WeeklyQuotaReading, now: Date): boolean {
  return reading.sourceStatus === "ok"
    && Number.isFinite(reading.usedPercent)
    && Number.isFinite(reading.remainingPercent)
    && reading.usedPercent >= 0 && reading.usedPercent <= 100
    && reading.remainingPercent >= 0 && reading.remainingPercent <= 100
    && Math.abs(reading.usedPercent + reading.remainingPercent - 100) <= 1.5
    && Math.abs(reading.windowMinutes - WEEKLY_MINUTES) <= 60
    && reading.fetchedAt.getTime() - now.getTime() <= 60_000
    && reading.resetsAt.getTime() > reading.fetchedAt.getTime()
    && reading.resetsAt.getTime() - reading.fetchedAt.getTime() <= 8 * 86_400_000;
}

function isValidWeeklyWindow(window: Partial<QuotaWindow> | undefined, now: Date): window is QuotaWindow {
  return isValidWindow(window)
    && Math.abs(window.windowMinutes - WEEKLY_MINUTES) <= 60
    && Math.abs(window.usedPercent + window.remainingPercent - 100) <= 1.5
    && window.resetsAt.getTime() > now.getTime();
}

function makeObservation(
  reading: WeeklyQuotaReading,
  canonicalResetAt: Date,
  cycleID: number,
  segmentID: number,
  qualityFlags: WeeklyQualityFlag[] = [],
): WeeklyObservation {
  return { fetchedAt: reading.fetchedAt, canonicalResetAt, usedPercent: reading.usedPercent, remainingPercent: reading.remainingPercent, cycleID, segmentID, qualityFlags };
}

function hasAlternatingTail(readings: WeeklyQuotaReading[]): boolean {
  if (readings.length < 5) return false;
  const tail = readings.slice(-5);
  return sameStream(tail[0], tail[2]) && sameStream(tail[2], tail[4]) && sameStream(tail[1], tail[3]) && !sameStream(tail[0], tail[1]);
}

function sameStream(left: WeeklyQuotaReading, right: WeeklyQuotaReading): boolean {
  return Math.abs(left.usedPercent - right.usedPercent) < 0.5
    && Math.abs(left.resetsAt.getTime() - right.resetsAt.getTime()) <= RESET_CLUSTER_TOLERANCE_MS;
}

function isConfirmed(readings: WeeklyQuotaReading[]): boolean {
  return readings.length >= 3 && readings.at(-1)!.fetchedAt.getTime() - readings[0].fetchedAt.getTime() >= CONFIRMATION_SPAN_MS;
}

function medianDate(dates: Date[]): Date {
  return new Date(median(dates.map((date) => date.getTime())));
}

function sampleWeeklyObservations(observations: WeeklyObservation[]): WeeklyObservation[] {
  const sampled: WeeklyObservation[] = [];
  for (const observation of observations) {
    const previous = sampled.at(-1);
    if (!previous) { sampled.push(observation); continue; }
    const bucket = Math.floor(observation.fetchedAt.getTime() / 300_000);
    const previousBucket = Math.floor(previous.fetchedAt.getTime() / 300_000);
    const transition = observation.usedPercent !== previous.usedPercent || observation.cycleID !== previous.cycleID || observation.segmentID !== previous.segmentID;
    if (bucket !== previousBucket || transition || observation.qualityFlags.length) sampled.push(observation);
  }
  return sampled;
}

function activeCycleAndSegment(observations: WeeklyObservation[]): WeeklyObservation[] {
  const last = observations.at(-1);
  return last ? observations.filter((item) => item.cycleID === last.cycleID && item.segmentID === last.segmentID) : [];
}

function qualifiedPaceBand(observations: WeeklyObservation[]): PaceBand | null {
  const first = observations[0];
  const last = observations.at(-1);
  if (!first || !last || last.fetchedAt.getTime() - first.fetchedAt.getTime() < MINIMUM_COVERAGE_MS || upwardTransitionCount(observations) === 0) return null;
  return robustPaceBand(observations);
}

function robustPaceBand(observations: WeeklyObservation[]): PaceBand | null {
  let candidates: Array<PaceBand & { midpoint: number }> = [];
  for (let earlier = 0; earlier < observations.length; earlier += 1) {
    for (let later = earlier + 1; later < observations.length; later += 1) {
      const duration = observations[later].fetchedAt.getTime() - observations[earlier].fetchedAt.getTime();
      if (duration < 30 * 60_000) continue;
      const first = quantizedInterval(observations[earlier].usedPercent);
      const second = quantizedInterval(observations[later].usedPercent);
      const scale = 86_400_000 / duration;
      const lower = Math.max(0, second.lower - first.upper) * scale;
      const upper = Math.max(0, second.upper - first.lower) * scale;
      candidates.push({ lower, upper, midpoint: (lower + upper) / 2 });
    }
  }
  if (!candidates.length) return null;
  if (candidates.length >= 5) {
    const center = median(candidates.map((item) => item.midpoint));
    const mad = median(candidates.map((item) => Math.abs(item.midpoint - center)));
    const tolerance = Math.max(0.01, 3 * mad);
    candidates = candidates.filter((item) => Math.abs(item.midpoint - center) <= tolerance);
  }
  return candidates.length ? { lower: median(candidates.map((item) => item.lower)), upper: median(candidates.map((item) => item.upper)) } : null;
}

function quantizedInterval(value: number): PercentageBand {
  if (Math.abs(value - Math.round(value)) < 0.000_001) return { lower: value, upper: Math.min(100, value + 1) };
  const resolution = Math.abs(value * 10 - Math.round(value * 10)) < 0.000_001 ? 0.1 : Math.abs(value * 100 - Math.round(value * 100)) < 0.000_001 ? 0.01 : 0.001;
  return { lower: Math.max(0, value - resolution / 2), upper: Math.min(100, value + resolution / 2) };
}

function upwardTransitionCount(observations: WeeklyObservation[]): number {
  let count = 0;
  for (let index = 1; index < observations.length; index += 1) if (observations[index].usedPercent > observations[index - 1].usedPercent) count += 1;
  return count;
}

function median(values: number[]): number {
  const sorted = values.slice().sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle];
}

function makeWeeklyForecast(
  state: WeeklyRunwayForecast["state"],
  confidence: WeeklyRunwayForecast["confidence"],
  window: QuotaWindow,
  elapsedPercent: number,
  daysUntilReset: number,
  sustainableRatePerDay: number,
  recentRateBandPerDay: PaceBand | null,
  cycleRateBandPerDay: PaceBand | null,
  projectedRemainingBandAtReset: PercentageBand | null,
  next24HourBudget: number,
): WeeklyRunwayForecast {
  return { state, confidence, usedPercent: window.usedPercent, remainingPercent: window.remainingPercent, elapsedPercent, daysUntilReset, sustainableRatePerDay, recentRateBandPerDay, cycleRateBandPerDay, projectedRemainingBandAtReset, next24HourBudget };
}

function unavailableWeeklyForecast(): WeeklyRunwayForecast {
  return { state: "unavailable", confidence: "low", usedPercent: null, remainingPercent: null, elapsedPercent: null, daysUntilReset: null, sustainableRatePerDay: null, recentRateBandPerDay: null, cycleRateBandPerDay: null, projectedRemainingBandAtReset: null, next24HourBudget: null };
}
