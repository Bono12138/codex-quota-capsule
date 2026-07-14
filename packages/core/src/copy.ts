import type { CapsuleLevel, ObservedUsageSummary, PercentageBand } from "./model";

export type DisplayLocale = "zh-Hans" | "zh-Hant" | "en";

const COPY_BANK: Record<CapsuleLevel, string[]> = {
  safe: [
    "放心冲。",
    "这速度挺健康。",
    "油箱还稳。",
  ],
  watch: [
    "别突然开大活。",
    "现在开始看着点用。",
    "能撑，但别加速。",
  ],
  danger: [
    "先停大任务。",
    "按这个速度撑不到重置。",
    "慢点用，快见底了。",
  ],
  unknown: [
    "先确认数据源。",
    "读不到数据，不报安全。",
    "状态未知，别硬猜。",
  ],
};

export function pickCapsuleCopy(level: CapsuleLevel, seed = 0): string {
  const lines = COPY_BANK[level];
  return lines[Math.abs(seed) % lines.length];
}

export function formatWeeklyProjection(band: PercentageBand | null, locale: DisplayLocale): string {
  if (!band || !Number.isFinite(band.lower) || !Number.isFinite(band.upper)) {
    if (locale === "zh-Hans") return "正在积累可靠的周速度预测";
    if (locale === "zh-Hant") return "正在累積可靠的週速度預測";
    return "Building a reliable weekly pace forecast";
  }
  const lower = Math.min(band.lower, band.upper);
  const upper = Math.max(band.lower, band.upper);
  if (upper < 0) {
    if (locale === "zh-Hans") return "照最近速度，本周额度可能在重置前用完";
    if (locale === "zh-Hant") return "照最近速度，本週額度可能在重設前用完";
    return "At the recent pace, weekly quota may run out before reset";
  }
  if (lower < 0) {
    const maximum = Math.round(upper);
    if (locale === "zh-Hans") return `按较快节奏可能提前用完；较慢情景重置时最多剩 ${maximum}%`;
    if (locale === "zh-Hant") return `按較快節奏可能提前用完；較慢情境重設時最多剩 ${maximum}%`;
    return `The faster scenario may run out early; the slower scenario leaves at most ${maximum}% at reset`;
  }
  const range = `${Math.round(lower)}%–${Math.round(upper)}%`;
  if (locale === "zh-Hans") return `照最近速度，重置时预计剩 ${range}`;
  if (locale === "zh-Hant") return `照最近速度，重設時預計剩 ${range}`;
  return `At the recent pace, ${range} should remain at reset`;
}

export function formatObservedUsage(summary: ObservedUsageSummary, locale: DisplayLocale): string {
  if (!Number.isFinite(summary.coverageSeconds) || summary.coverageSeconds <= 0
    || !Number.isFinite(summary.increaseBand.lower) || !Number.isFinite(summary.increaseBand.upper)) return "";
  const totalMinutes = Math.max(1, Math.round(summary.coverageSeconds / 60));
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  const lower = Math.round(Math.max(0, summary.increaseBand.lower));
  const upper = Math.round(Math.max(0, summary.increaseBand.upper));
  if (locale === "zh-Hans") {
    const duration = hours > 0 ? (minutes > 0 ? `${hours} 小时 ${minutes} 分钟` : `${hours} 小时`) : `${minutes} 分钟`;
    return `近 ${duration}已用约 ${lower}%–${upper}%`;
  }
  if (locale === "zh-Hant") {
    const duration = hours > 0 ? (minutes > 0 ? `${hours} 小時 ${minutes} 分鐘` : `${hours} 小時`) : `${minutes} 分鐘`;
    return `近 ${duration}已用約 ${lower}%–${upper}%`;
  }
  const duration = hours > 0 ? (minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`) : `${minutes}m`;
  return `About ${lower}%–${upper}% used over the last ${duration}`;
}
