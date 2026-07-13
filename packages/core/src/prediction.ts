import type {
  AgentQuotaSnapshot,
  PaceBand,
  PercentageBand,
  QuotaWindow,
  WeeklyObservation,
  WeeklyQualityFlag,
  WeeklyQualityResult,
  WeeklyQuotaReading,
  WeeklyRunwayForecast,
} from "./model";

const WEEKLY_MINUTES = 10_080;
const RESET_CLUSTER_TOLERANCE_MS = 5 * 60_000;
const FRESHNESS_THRESHOLD_MS = 180_000;
const CONFIRMATION_SPAN_MS = 120_000;
const MINIMUM_COVERAGE_MS = 6 * 60 * 60_000;
const RECENT_HORIZON_MS = 24 * 60 * 60_000;
const RESERVE_PERCENT = 5;

export function analyzeWeeklyQuality(readings: WeeklyQuotaReading[], now = new Date()): WeeklyQualityResult {
  let ordered = readings
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
  const inheritedFlags = new Set<WeeklyQualityFlag>();
  const alternationEnd = lastAlternatingEndIndex(ordered);
  if (alternationEnd !== null) {
    const recovery = ordered.slice(alternationEnd);
    if (!isConfirmedAlternationRecovery(recovery)) {
      const lastAlternatingReading = ordered[alternationEnd];
      return {
        state: "unstable",
        observations: [makeObservation(lastAlternatingReading, lastAlternatingReading.resetsAt, 0, 0)],
        canonicalResetAt: lastAlternatingReading.resetsAt,
        flags: ["alternatingStream"],
      };
    }
    ordered = recovery;
    inheritedFlags.add("alternatingStream");
  }

  let accepted: WeeklyObservation[] = [];
  const flags = inheritedFlags;
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
  const active = quality.state === "stable" ? activeCycleAndSegment(quality.observations) : [];
  const last24HourUsage = observedLast24HourUsageBand(active, now);
  const trend = trendPoints(active);

  if (window.remainingPercent <= 0) {
    return makeWeeklyForecast("exhausted", "low", window, elapsedPercent, daysRemaining, 0, null, null, { lower: 0, upper: 0 }, 0, last24HourUsage, { earliest: now, latest: now }, trend);
  }
  if (quality.state === "stale" || quality.state === "unavailable") {
    return { ...unavailableWeeklyForecast(), usedPercent: window.usedPercent, remainingPercent: window.remainingPercent, elapsedPercent, daysUntilReset: daysRemaining };
  }
  if (quality.state !== "stable") {
    return makeWeeklyForecast("calibrating", "low", window, elapsedPercent, daysRemaining, sustainable, null, null, null, budget);
  }

  const latest = active.at(-1);
  if (!latest || Math.abs(latest.usedPercent - window.usedPercent) > 1.5 || Math.abs(latest.canonicalResetAt.getTime() - window.resetsAt.getTime()) > RESET_CLUSTER_TOLERANCE_MS) {
    return makeWeeklyForecast("calibrating", "low", window, elapsedPercent, daysRemaining, sustainable, null, null, null, budget, last24HourUsage, null, trend);
  }
  const cycleBand = qualifiedPaceBand(active);
  const recent = active.filter((observation) => now.getTime() - observation.fetchedAt.getTime() <= RECENT_HORIZON_MS);
  const recentBand = qualifiedPaceBand(recent);
  if (!cycleBand || !recentBand) {
    return makeWeeklyForecast("calibrating", "low", window, elapsedPercent, daysRemaining, sustainable, recentBand, cycleBand, null, budget, last24HourUsage, null, trend);
  }

  const pace = { lower: Math.min(cycleBand.lower, recentBand.lower), upper: Math.max(cycleBand.upper, recentBand.upper) };
  const projected = {
    lower: window.remainingPercent - pace.upper * daysRemaining,
    upper: window.remainingPercent - pace.lower * daysRemaining,
  };
  const state = projected.lower >= RESERVE_PERCENT ? "enough" : projected.upper < 0 ? "mayRunOut" : "watch";
  const coverage = active.at(-1)!.fetchedAt.getTime() - active[0].fetchedAt.getTime();
  const confidence = coverage >= RECENT_HORIZON_MS && upwardTransitionCount(active) >= 3 ? "high" : "medium";
  const exhaustion = exhaustionRange(window.remainingPercent, pace, now);
  return makeWeeklyForecast(state, confidence, window, elapsedPercent, daysRemaining, sustainable, recentBand, cycleBand, projected, budget, last24HourUsage, exhaustion, trend);
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

function isValidWindow(window: Partial<QuotaWindow> | undefined): window is QuotaWindow {
  return typeof window?.label === "string"
    && typeof window.windowMinutes === "number"
    && Number.isInteger(window.windowMinutes)
    && window.windowMinutes > 0
    && typeof window.usedPercent === "number"
    && Number.isFinite(window.usedPercent)
    && window.usedPercent >= 0
    && window.usedPercent <= 100
    && typeof window.remainingPercent === "number"
    && Number.isFinite(window.remainingPercent)
    && window.remainingPercent >= 0
    && window.remainingPercent <= 100
    && window.resetsAt instanceof Date
    && Number.isFinite(window.resetsAt.getTime());
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

function lastAlternatingEndIndex(readings: WeeklyQuotaReading[]): number | null {
  for (let endIndex = readings.length - 1; endIndex >= 4; endIndex -= 1) {
    const tail = readings.slice(endIndex - 4, endIndex + 1);
    if (sameStream(tail[0], tail[2])
      && sameStream(tail[2], tail[4])
      && sameStream(tail[1], tail[3])
      && !sameStream(tail[0], tail[1])) {
      return endIndex;
    }
  }
  return null;
}

function isConfirmedAlternationRecovery(readings: WeeklyQuotaReading[]): boolean {
  const confirmation = readings.slice(0, 3);
  if (!isConfirmed(confirmation)) return false;
  const first = confirmation[0];
  const resetIsConsistent = confirmation.every((reading) =>
    Math.abs(reading.resetsAt.getTime() - first.resetsAt.getTime()) <= RESET_CLUSTER_TOLERANCE_MS);
  const usageIsConsistent = confirmation.slice(1).every((reading, index) => {
    const previous = confirmation[index];
    return reading.usedPercent >= previous.usedPercent && reading.usedPercent - previous.usedPercent <= 1.5;
  });
  return resetIsConsistent && usageIsConsistent;
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

function observedLast24HourUsageBand(observations: WeeklyObservation[], now: Date): PercentageBand | null {
  const latest = observations.at(-1);
  if (!latest) return null;
  const cutoff = now.getTime() - RECENT_HORIZON_MS;
  const baseline = observations.filter((observation) => observation.fetchedAt.getTime() <= cutoff).at(-1);
  if (!baseline || cutoff - baseline.fetchedAt.getTime() > 3 * 60 * 60_000 || latest.fetchedAt.getTime() <= baseline.fetchedAt.getTime()) return null;
  const first = quantizedInterval(baseline.usedPercent);
  const last = quantizedInterval(latest.usedPercent);
  return { lower: Math.max(0, last.lower - first.upper), upper: Math.max(0, last.upper - first.lower) };
}

function trendPoints(observations: WeeklyObservation[], limit = 32): Array<{ at: Date; usedPercent: number }> {
  if (observations.length <= limit || limit <= 1) {
    return observations.map((observation) => ({ at: observation.fetchedAt, usedPercent: observation.usedPercent }));
  }
  const stride = (observations.length - 1) / (limit - 1);
  return Array.from({ length: limit }, (_, index) => {
    const observation = observations[Math.round(index * stride)];
    return { at: observation.fetchedAt, usedPercent: observation.usedPercent };
  });
}

function exhaustionRange(remainingPercent: number, pace: PaceBand, now: Date): { earliest: Date; latest: Date | null } | null {
  if (pace.upper <= 0) return null;
  return {
    earliest: new Date(now.getTime() + (remainingPercent / pace.upper) * 86_400_000),
    latest: pace.lower > 0 ? new Date(now.getTime() + (remainingPercent / pace.lower) * 86_400_000) : null,
  };
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
  last24HourUsageBand: PercentageBand | null = null,
  estimatedEmptyAtRange: { earliest: Date; latest: Date | null } | null = null,
  currentCycleTrend: Array<{ at: Date; usedPercent: number }> = [],
): WeeklyRunwayForecast {
  return { state, confidence, usedPercent: window.usedPercent, remainingPercent: window.remainingPercent, elapsedPercent, daysUntilReset, sustainableRatePerDay, recentRateBandPerDay, cycleRateBandPerDay, last24HourUsageBand, projectedRemainingBandAtReset, estimatedEmptyAtRange, next24HourBudget, currentCycleTrend };
}

function unavailableWeeklyForecast(): WeeklyRunwayForecast {
  return { state: "unavailable", confidence: "low", usedPercent: null, remainingPercent: null, elapsedPercent: null, daysUntilReset: null, sustainableRatePerDay: null, recentRateBandPerDay: null, cycleRateBandPerDay: null, last24HourUsageBand: null, projectedRemainingBandAtReset: null, estimatedEmptyAtRange: null, next24HourBudget: null, currentCycleTrend: [] };
}
