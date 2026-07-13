import type { CapsuleLevel } from "./model";

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
