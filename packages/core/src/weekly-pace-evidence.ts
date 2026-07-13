import type { PaceBand, PaceEvidence, PercentageBand, QuotaWindow, WeeklyObservation } from "./model";

const DAY_MS = 86_400_000;
const MINIMUM_PAIR_MS = 30 * 60_000;
const RECENT_HORIZON_MS = 24 * 60 * 60_000;

export function cycleEvidence(window: QuotaWindow, now: Date): PaceEvidence | null {
  const duration = window.windowMinutes * 60_000;
  const cycleStart = window.resetsAt.getTime() - duration;
  const elapsed = now.getTime() - cycleStart;
  if (duration <= 0 || elapsed <= 0 || elapsed > duration || window.resetsAt.getTime() <= now.getTime()
    || !Number.isFinite(window.usedPercent) || window.usedPercent < 0 || window.usedPercent > 100) return null;

  const interval = quantizedInterval(window.usedPercent);
  const elapsedDays = elapsed / DAY_MS;
  const elapsedFraction = clamp(elapsed / duration, 0, 1);
  return {
    kind: "cycle",
    bandPerDay: { lower: interval.lower / elapsedDays, upper: interval.upper / elapsedDays },
    reliability: clamp(0.10 + 0.45 * Math.sqrt(elapsedFraction), 0.10, 0.55),
    transitionCount: 0,
    coverageHours: elapsed / 3_600_000,
  };
}

export function recentEvidence(observations: WeeklyObservation[], now: Date): PaceEvidence | null {
  const cutoff = now.getTime() - RECENT_HORIZON_MS;
  const eligible = observations.filter((item) => item.fetchedAt.getTime() >= cutoff && item.fetchedAt.getTime() <= now.getTime());
  const transitions = countUpwardTransitions(eligible);
  const first = eligible[0];
  const last = eligible.at(-1);
  const band = transitions > 0 ? robustBand(eligible) : null;
  if (!first || !last || !band) return null;

  const coverage = last.fetchedAt.getTime() - first.fetchedAt.getTime();
  return {
    kind: "recent",
    bandPerDay: band,
    reliability: clamp(0.20 + 0.10 * Math.min(transitions, 4) + 0.25 * Math.sqrt(Math.min(1, coverage / RECENT_HORIZON_MS)), 0.20, 0.85),
    transitionCount: transitions,
    coverageHours: coverage / 3_600_000,
  };
}

export function activityEvidence(observations: WeeklyObservation[], now: Date): PaceEvidence | null {
  const eligible = observations.filter((item) => item.fetchedAt.getTime() <= now.getTime());
  const transitionIndexes: number[] = [];
  for (let index = 1; index < eligible.length; index += 1) {
    if (eligible[index].usedPercent > eligible[index - 1].usedPercent) transitionIndexes.push(index);
  }
  const firstTransition = transitionIndexes[0];
  const lastTransition = transitionIndexes.at(-1);
  if (firstTransition === undefined || lastTransition === undefined) return null;

  const baseline = eligible[firstTransition - 1];
  const latestTransition = eligible[lastTransition];
  const coverage = now.getTime() - baseline.fetchedAt.getTime();
  if (coverage < MINIMUM_PAIR_MS) return null;
  const first = quantizedInterval(baseline.usedPercent);
  const last = quantizedInterval(latestTransition.usedPercent);
  const scale = DAY_MS / coverage;
  const band = {
    lower: Math.max(0, last.lower - first.upper) * scale,
    upper: Math.max(0, last.upper - first.lower) * scale,
  };
  if (band.upper <= 0) return null;

  const idle = Math.max(0, now.getTime() - latestTransition.fetchedAt.getTime());
  const idleFactor = Math.max(0.5, Math.exp(-idle / (48 * 3_600_000)));
  return {
    kind: "activity",
    bandPerDay: band,
    reliability: clamp((0.18 + 0.08 * Math.min(transitionIndexes.length, 4) + 0.18 * Math.sqrt(Math.min(1, coverage / RECENT_HORIZON_MS))) * idleFactor, 0.12, 0.72),
    transitionCount: transitionIndexes.length,
    coverageHours: coverage / 3_600_000,
  };
}

export function historicalEvidence(observations: WeeklyObservation[], currentCycleID: number): PaceEvidence | null {
  const cycles = new Map<number, WeeklyObservation[]>();
  for (const observation of observations) {
    if (observation.cycleID === currentCycleID) continue;
    const cycle = cycles.get(observation.cycleID) ?? [];
    cycle.push(observation);
    cycles.set(observation.cycleID, cycle);
  }

  const candidates: Array<{ band: PaceBand; reliability: number; transitions: number; coverage: number }> = [];
  for (const cycle of cycles.values()) {
    const segments = new Map<number, WeeklyObservation[]>();
    for (const observation of cycle) {
      const segment = segments.get(observation.segmentID) ?? [];
      segment.push(observation);
      segments.set(observation.segmentID, segment);
    }
    const segmentCandidates = [...segments.values()].map((segment) => {
      const ordered = segment.slice().sort((left, right) => left.fetchedAt.getTime() - right.fetchedAt.getTime());
      const first = ordered[0];
      const last = ordered.at(-1);
      if (!first || !last) return null;
      const coverage = last.fetchedAt.getTime() - first.fetchedAt.getTime();
      const transitions = countUpwardTransitions(ordered);
      if (coverage < 48 * 3_600_000 || transitions < 2) return null;
      const start = quantizedInterval(first.usedPercent);
      const end = quantizedInterval(last.usedPercent);
      const scale = DAY_MS / coverage;
      return {
        band: { lower: Math.max(0, end.lower - start.upper) * scale, upper: Math.max(0, end.upper - start.lower) * scale },
        reliability: clamp(0.15 + 0.03 * Math.min(transitions, 4) + 0.08 * Math.min(1, coverage / (7 * DAY_MS)), 0.15, 0.35),
        transitions,
        coverage,
      };
    }).filter((item): item is NonNullable<typeof item> => item !== null)
      .sort((left, right) => right.coverage - left.coverage);
    if (segmentCandidates[0]) candidates.push(segmentCandidates[0]);
  }

  if (!candidates.length) return null;
  return {
    kind: "historical",
    bandPerDay: {
      lower: median(candidates.map((item) => item.band.lower)),
      upper: median(candidates.map((item) => item.band.upper)),
    },
    reliability: Math.min(0.35, candidates.reduce((sum, item) => sum + item.reliability, 0) / candidates.length),
    transitionCount: candidates.reduce((sum, item) => sum + item.transitions, 0),
    coverageHours: Math.max(...candidates.map((item) => item.coverage)) / 3_600_000,
  };
}

export function fusePaceEvidence(evidence: PaceEvidence[]): PaceBand | null {
  if (!evidence.length) return null;
  return {
    lower: weightedQuantile(evidence.map((item) => [item.bandPerDay.lower, item.reliability]), 0.25),
    upper: weightedQuantile(evidence.map((item) => [item.bandPerDay.upper, item.reliability]), 0.75),
  };
}

export function countUpwardTransitions(observations: WeeklyObservation[]): number {
  let count = 0;
  for (let index = 1; index < observations.length; index += 1) {
    if (observations[index].usedPercent > observations[index - 1].usedPercent) count += 1;
  }
  return count;
}

export function quantizedInterval(value: number): PercentageBand {
  return { lower: Math.max(0, value - 0.5), upper: Math.min(100, value + 0.5) };
}

function robustBand(observations: WeeklyObservation[]): PaceBand | null {
  let candidates: Array<PaceBand & { midpoint: number }> = [];
  for (let earlier = 0; earlier < observations.length; earlier += 1) {
    for (let later = earlier + 1; later < observations.length; later += 1) {
      const duration = observations[later].fetchedAt.getTime() - observations[earlier].fetchedAt.getTime();
      if (duration < MINIMUM_PAIR_MS) continue;
      const first = quantizedInterval(observations[earlier].usedPercent);
      const second = quantizedInterval(observations[later].usedPercent);
      const scale = DAY_MS / duration;
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
  return candidates.length ? {
    lower: median(candidates.map((item) => item.lower)),
    upper: median(candidates.map((item) => item.upper)),
  } : null;
}

function weightedQuantile(values: Array<[number, number]>, quantile: number): number {
  const ordered = values.slice().sort((left, right) => left[0] - right[0]);
  const total = ordered.reduce((sum, item) => sum + Math.max(0.001, item[1]), 0);
  let cumulative = 0;
  for (const item of ordered) {
    cumulative += Math.max(0.001, item[1]);
    if (cumulative >= total * quantile) return item[0];
  }
  return ordered.at(-1)?.[0] ?? 0;
}

function median(values: number[]): number {
  const ordered = values.slice().sort((left, right) => left - right);
  const middle = Math.floor(ordered.length / 2);
  return ordered.length % 2 === 0 ? (ordered[middle - 1] + ordered[middle]) / 2 : ordered[middle];
}

function clamp(value: number, lower: number, upper: number): number {
  return Math.min(upper, Math.max(lower, value));
}
