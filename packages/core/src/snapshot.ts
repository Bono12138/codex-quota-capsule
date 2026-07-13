import type { AgentQuotaSnapshot } from "./model";

export type QuotaSnapshotRecord = {
  id: string;
  capturedAt: Date;
  fetchedAt: Date;
  provider: string;
  sourceStatus: AgentQuotaSnapshot["sourceStatus"];
  source: string;
  windowType: "weekly" | null;
  windowMinutes: number | null;
  usedPercent: number | null;
  remainingPercent: number | null;
  resetsAt: Date | null;
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
  sourceStatus?: AgentQuotaSnapshot["sourceStatus"];
};

export function createSnapshotRecord(
  snapshot: AgentQuotaSnapshot,
  options: CreateSnapshotRecordOptions,
): QuotaSnapshotRecord {
  const window = snapshot.weeklyWindow;
  const validWeekly = window
    && Math.abs((window.windowMinutes ?? 0) - 10_080) <= 60
    && typeof window.usedPercent === "number"
    && typeof window.remainingPercent === "number"
    && window.resetsAt instanceof Date;
  const dataAgeSeconds = Math.max(0, Math.round((options.capturedAt.getTime() - snapshot.fetchedAt.getTime()) / 1000));

  return {
    id: `${options.capturedAt.toISOString()}-${snapshot.provider}-${validWeekly ? "weekly" : "unknown"}`,
    capturedAt: options.capturedAt,
    fetchedAt: snapshot.fetchedAt,
    provider: snapshot.provider,
    sourceStatus: snapshot.sourceStatus,
    source: options.source ?? snapshot.provider,
    windowType: validWeekly ? "weekly" : null,
    windowMinutes: validWeekly ? window.windowMinutes! : null,
    usedPercent: validWeekly ? window.usedPercent! : null,
    remainingPercent: validWeekly ? window.remainingPercent! : null,
    resetsAt: validWeekly ? window.resetsAt! : null,
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
      if (filter.sourceStatus && record.sourceStatus !== filter.sourceStatus) return false;
      return true;
    });
  }
}
