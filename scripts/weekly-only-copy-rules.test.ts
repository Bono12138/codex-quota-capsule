import { expect, test } from "vitest";

import { retiredProductCopyReason } from "./weekly-only-copy-rules";

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
