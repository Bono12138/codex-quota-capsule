import { expect, test } from "vitest";

import { ambiguousResetCopyReason, retiredProductCopyReason } from "./weekly-only-copy-rules";

test("rejects retired English weekly state labels regardless of case", () => {
  for (const copy of ["Safe", "WATCH", "danger", "Unknown"]) {
    expect(retiredProductCopyReason(`Status: ${copy}`)).toBe("retired English weekly state label");
  }
});

test("rejects superseded English enough and unavailable display labels", () => {
  expect(retiredProductCopyReason("Enough.")).toBe("retired English weekly state label");
  expect(retiredProductCopyReason("- Unavailable: live read failed")).toBe(
    "retired English weekly state label",
  );
  expect(retiredProductCopyReason("`state`: enough / unavailable")).toBeNull();
});

test("rejects retired Chinese weekly state sequences and badge examples", () => {
  expect(retiredProductCopyReason("安全 / 注意 / 危险 / 未知")).toBe(
    "retired Chinese weekly state label",
  );
  expect(retiredProductCopyReason("菜单栏：安全 5%")).toBe("retired Chinese weekly state label");
});

test("does not confuse ordinary safety and attention copy with state labels", () => {
  expect(retiredProductCopyReason("保留安全边界，并注意：这只是预测。")).toBeNull();
});

test("allows reset-credit lifecycle and privacy terms without weakening weekly labels", () => {
  expect(retiredProductCopyReason("Reset-credit history stays privacy-safe and a disappearance may remain unknown.")).toBeNull();
  expect(retiredProductCopyReason("重置券未到期消失时保持 unknown。")).toBeNull();
  expect(retiredProductCopyReason("Weekly state: unknown")).toBe("retired English weekly state label");
});

test("rejects quota reset copy that calls the reset a data refresh", () => {
  expect(ambiguousResetCopyReason('return "本周额度已用尽，刷新后会自动恢复"'))
    .toBe("quota reset is mislabeled as refresh");
  expect(ambiguousResetCopyReason("周额度刷新：周一 08:00"))
    .toBe("quota reset is mislabeled as refresh");
  expect(ambiguousResetCopyReason("数据更新于 13:49，下次自动刷新约 47 秒后"))
    .toBeNull();
});
