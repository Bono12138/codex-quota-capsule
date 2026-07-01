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
  shortWindow?: QuotaWindow;
  weeklyWindow?: Partial<QuotaWindow>;
  resetCount?: number;
  errorMessage?: string;
};

export type CapsuleLevel = "safe" | "watch" | "danger" | "unknown";

export type CapsulePrediction = {
  level: CapsuleLevel;
  canReachReset: boolean | null;
  elapsedPercent: number | null;
  projectedRemainingAtReset: number | null;
  estimatedEmptyAt: Date | null;
  headline: string;
  detail: string;
};

export type PredictionOptions = {
  now: Date;
  watchRemainingThreshold?: number;
  justResetMinutes?: number;
};

