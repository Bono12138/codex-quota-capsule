import { readFileSync } from "node:fs";
import { expect, test } from "vitest";

test("the floating panel uses one menu layer with top-level language actions", () => {
  const source = readFileSync(
    new URL("../Sources/QuotaCapsuleMac/CapsuleViews.swift", import.meta.url),
    "utf8",
  );
  const start = source.indexOf("struct PanelQuickActionsView");
  const end = source.indexOf("struct OverviewStatsGrid", start);
  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);

  const panelActions = source.slice(start, end);
  expect(panelActions.match(/\bMenu\s*\{/g) ?? []).toHaveLength(1);
  expect(panelActions).not.toContain("languageSubmenu");
  expect(panelActions).toContain("store.selectLocale(.zhHans)");
  expect(panelActions).toContain("store.selectLocale(.zhHant)");
  expect(panelActions).toContain("store.selectLocale(.en)");
});
