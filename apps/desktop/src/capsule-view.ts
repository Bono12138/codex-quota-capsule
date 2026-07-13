import type { CapsuleLevel, PercentageBand, WeeklyRunwayForecast, WeeklyRunwayState } from "@quota-capsule/core";

export type CapsuleDisplayMetric = {
  label: string;
  value: string;
  numericValue?: number | null;
};

export type CapsuleDisplayModel = {
  tone: CapsuleLevel;
  statusLabel: string;
  defaultText: string;
  compactDetail: string;
  detailMetrics: CapsuleDisplayMetric[];
  confidenceText: string;
};

const STATUS_LABELS: Record<WeeklyRunwayState, string> = {
  unavailable: "数据暂不可用",
  exhausted: "已用尽",
  calibrating: "正在校准",
  enough: "够用",
  watch: "偏快",
  mayRunOut: "可能不够",
};

export function createCapsuleDisplayModel(forecast: WeeklyRunwayForecast): CapsuleDisplayModel {
  const elapsed = safePercent(forecast.elapsedPercent);
  const used = safePercent(forecast.usedPercent);
  return {
    tone: toneFor(forecast.state),
    statusLabel: STATUS_LABELS[forecast.state],
    defaultText: defaultText(forecast),
    compactDetail: used === null ? "" : `本周已用 ${formatNumber(used)}%`,
    detailMetrics: [
      { label: "本周时间", value: formatPercent(elapsed), numericValue: elapsed },
      { label: "本周已用", value: formatPercent(used), numericValue: used },
      { label: "最近 24 小时", value: formatUsageBand(forecast.last24HourUsageBand), numericValue: null },
      { label: "未来 24 小时建议", value: formatBudget(forecast.next24HourBudget), numericValue: null },
    ],
    confidenceText: forecast.confidence === "high" ? "预测可信度：高" : forecast.confidence === "medium" ? "预测可信度：中" : "",
  };
}

function toneFor(state: WeeklyRunwayState): CapsuleLevel {
  if (state === "enough") return "safe";
  if (state === "watch") return "watch";
  if (state === "mayRunOut" || state === "exhausted") return "danger";
  return "unknown";
}

function defaultText(forecast: WeeklyRunwayForecast): string {
  if (forecast.state === "unavailable") return "暂时没有可用的周额度数据";
  if (forecast.state === "exhausted") return "本周额度已用尽，刷新后会自动恢复";
  if (forecast.state === "calibrating") return "正在观察你的周速度，积累 6 小时有效数据后给出判断";
  if (forecast.state === "mayRunOut") return "照最近速度，本周额度可能在刷新前用完";
  const range = safeRange(forecast.projectedRemainingBandAtReset);
  return range
    ? `照最近速度，刷新时预计剩 ${formatNumber(range.lower)}%–${formatNumber(range.upper)}%`
    : "正在积累可靠的周速度预测";
}

function formatPercent(value: number | null): string {
  return value === null ? "未知" : `${formatNumber(value)}%`;
}

function formatUsageBand(band: PercentageBand | null): string {
  if (!band || !Number.isFinite(band.lower) || !Number.isFinite(band.upper) || band.lower < 0 || band.upper < band.lower) return "积累中";
  return `${formatNumber(band.lower)}–${formatNumber(band.upper)}%`;
}

function formatBudget(value: number | null): string {
  return value === null || !Number.isFinite(value) || value < 0 ? "积累中" : `≤${formatNumber(Math.min(100, value))}%`;
}

function safePercent(value: number | null): number | null {
  return value === null || !Number.isFinite(value) ? null : Math.min(100, Math.max(0, value));
}

function safeRange(band: PercentageBand | null): PercentageBand | null {
  if (!band || !Number.isFinite(band.lower) || !Number.isFinite(band.upper)) return null;
  const lower = Math.min(100, Math.max(0, band.lower));
  const upper = Math.min(100, Math.max(0, band.upper));
  return { lower: Math.min(lower, upper), upper: Math.max(lower, upper) };
}

function formatNumber(value: number): string {
  return Math.abs(Math.round(value) - value) < 0.05 ? String(Math.round(value)) : value.toFixed(1);
}
