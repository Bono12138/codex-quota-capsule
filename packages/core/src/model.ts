export type SourceStatus = "ok" | "stale" | "error";

export type QuotaWindow = {
  label: string;
  windowMinutes: number;
  usedPercent: number;
  remainingPercent: number;
  resetsAt: Date;
};

export type AgentQuotaSnapshot = {
  provider: string;
  sourceStatus: SourceStatus;
  fetchedAt: Date;
  weeklyWindow?: QuotaWindow;
  errorMessage?: string;
};

export type CapsuleLevel = "safe" | "watch" | "danger" | "unknown";

export type WeeklyQuotaReading = {
  provider: string;
  sourceStatus: SourceStatus;
  fetchedAt: Date;
  windowMinutes: number;
  usedPercent: number;
  remainingPercent: number;
  resetsAt: Date;
  errorMessage?: string;
};

export type WeeklyQualityState = "stable" | "calibrating" | "unstable" | "stale" | "unavailable";
export type WeeklyQualityFlag = "resetCandidate" | "correction" | "alternatingStream" | "resetJitter" | "staleSource";

export type WeeklyObservation = {
  fetchedAt: Date;
  canonicalResetAt: Date;
  usedPercent: number;
  remainingPercent: number;
  cycleID: number;
  segmentID: number;
  qualityFlags: WeeklyQualityFlag[];
};

export type WeeklyQualityResult = {
  state: WeeklyQualityState;
  observations: WeeklyObservation[];
  canonicalResetAt: Date | null;
  flags: WeeklyQualityFlag[];
};

export type PaceBand = { lower: number; upper: number };
export type PercentageBand = { lower: number; upper: number };
export type WeeklyRunwayState = "unavailable" | "exhausted" | "calibrating" | "enough" | "watch" | "mayRunOut";
export type ForecastConfidence = "low" | "medium" | "high";

export type WeeklyRunwayForecast = {
  state: WeeklyRunwayState;
  confidence: ForecastConfidence;
  usedPercent: number | null;
  remainingPercent: number | null;
  elapsedPercent: number | null;
  daysUntilReset: number | null;
  sustainableRatePerDay: number | null;
  recentRateBandPerDay: PaceBand | null;
  cycleRateBandPerDay: PaceBand | null;
  projectedRemainingBandAtReset: PercentageBand | null;
  next24HourBudget: number | null;
};
