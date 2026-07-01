import type { AgentQuotaSnapshot, CapsulePrediction, CapsuleLevel } from "@quota-capsule/core";

export type CapsuleDisplayMetric = {
  label: string;
  value: string;
  numericValue?: number | null;
};

export type CapsuleDisplayModel = {
  tone: CapsuleLevel;
  statusLabel: string;
  defaultText: string;
  detailMetrics: CapsuleDisplayMetric[];
  historyCta: string;
};

export function createCapsuleDisplayModel(
  _snapshot: AgentQuotaSnapshot,
  prediction: CapsulePrediction,
): CapsuleDisplayModel {
  const projected = prediction.projectedRemainingAtReset;

  return {
    tone: prediction.level,
    statusLabel: STATUS_LABELS[prediction.level],
    defaultText: compactText(prediction),
    detailMetrics: [
      { label: "时间进度", value: formatPercent(prediction.elapsedPercent), numericValue: prediction.elapsedPercent },
      { label: "额度已用", value: formatPercent(prediction.quotaUsedPercent), numericValue: prediction.quotaUsedPercent },
      { label: "当前速度", value: formatBurnRate(prediction), numericValue: null },
      { label: "刷新余量", value: projected === null ? "未知" : `${Math.round(projected)}%`, numericValue: projected },
    ],
    historyCta: "查看历史",
  };
}

const STATUS_LABELS: Record<CapsuleLevel, string> = {
  safe: "安全",
  watch: "注意",
  danger: "危险",
  unknown: "未知",
};

function compactText(prediction: CapsulePrediction): string {
  if (prediction.level === "unknown") return "暂时读不到额度";
  if (prediction.level === "danger" && prediction.estimatedEmptyAt) {
    return `预计 ${formatTime(prediction.estimatedEmptyAt)} 见底`;
  }
  if (prediction.headline.includes("够用到")) return prediction.headline.replace("按当前速度，", "");
  if (prediction.headline.includes("能撑到")) return prediction.headline.replace("，但余量不多", "");
  return prediction.headline;
}

function formatPercent(value: number | null): string {
  return value === null ? "未知" : `${Math.round(value)}%`;
}

function formatBurnRate(prediction: CapsulePrediction): string {
  if (!prediction.elapsedPercent || prediction.quotaUsedPercent === null || prediction.elapsedPercent <= 0) {
    return "未知";
  }

  return `${(prediction.quotaUsedPercent / prediction.elapsedPercent).toFixed(2)}x`;
}

function formatTime(date: Date): string {
  return new Intl.DateTimeFormat("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}
