import type { AgentQuotaSnapshot, CapsuleLevel, CapsulePrediction } from "./model";

export type QuotaSnapshotRecord = {
  id: string;
  capturedAt: Date;
  fetchedAt: Date;
  provider: string;
  sourceStatus: AgentQuotaSnapshot["sourceStatus"];
  source: string;
  windowType: string | null;
  usedPercent: number | null;
  remainingPercent: number | null;
  resetsAt: Date | null;
  timeElapsedPercent: number | null;
  burnRate: number | null;
  estimatedEmptyAt: Date | null;
  projectedRemainingAtReset: number | null;
  state: CapsuleLevel;
  dataAgeSeconds: number;
  appVersion: string;
  errorMessage?: string;
};

export type CreateSnapshotRecordOptions = {
  capturedAt: Date;
  appVersion: string;
  source?: string;
};

export type SnapshotListFilter = {
  provider?: string;
  state?: CapsuleLevel;
};

export function createSnapshotRecord(
  snapshot: AgentQuotaSnapshot,
  prediction: CapsulePrediction,
  options: CreateSnapshotRecordOptions,
): QuotaSnapshotRecord {
  const window = snapshot.shortWindow;
  const dataAgeSeconds = Math.max(0, Math.round((options.capturedAt.getTime() - snapshot.fetchedAt.getTime()) / 1000));
  const burnRate =
    prediction.elapsedPercent && prediction.quotaUsedPercent !== null && prediction.elapsedPercent > 0
      ? prediction.quotaUsedPercent / prediction.elapsedPercent
      : null;

  return {
    id: `${options.capturedAt.toISOString()}-${snapshot.provider}-${window?.label ?? "unknown"}`,
    capturedAt: options.capturedAt,
    fetchedAt: snapshot.fetchedAt,
    provider: snapshot.provider,
    sourceStatus: snapshot.sourceStatus,
    source: options.source ?? snapshot.provider,
    windowType: window?.label ?? null,
    usedPercent: window?.usedPercent ?? null,
    remainingPercent: window?.remainingPercent ?? null,
    resetsAt: window?.resetsAt ?? null,
    timeElapsedPercent: prediction.elapsedPercent,
    burnRate,
    estimatedEmptyAt: prediction.estimatedEmptyAt,
    projectedRemainingAtReset: prediction.projectedRemainingAtReset,
    state: prediction.level,
    dataAgeSeconds,
    appVersion: options.appVersion,
    errorMessage: snapshot.errorMessage,
  };
}

export class InMemorySnapshotStore {
  private readonly records: QuotaSnapshotRecord[] = [];

  add(record: QuotaSnapshotRecord): void {
    this.records.push(record);
  }

  list(filter: SnapshotListFilter = {}): QuotaSnapshotRecord[] {
    return this.records.filter((record) => {
      if (filter.provider && record.provider !== filter.provider) return false;
      if (filter.state && record.state !== filter.state) return false;
      return true;
    });
  }
}
