import { readFileSync } from "node:fs";
import { expect, test } from "vitest";

test("the floating panel exposes sibling one-layer language and More menus", () => {
  const source = readFileSync(
    new URL("../Sources/QuotaCapsuleMac/CapsuleViews.swift", import.meta.url),
    "utf8",
  );
  const start = source.indexOf("struct PanelQuickActionsView");
  const end = source.indexOf("struct OverviewStatsGrid", start);
  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);

  const panelActions = source.slice(start, end);
  expect(panelActions.match(/\bMenu\s*\{/g) ?? []).toHaveLength(2);
  expect(panelActions).toContain("languageMenu");

  const languageStart = panelActions.indexOf("private var languageMenu");
  const moreStart = panelActions.indexOf("private var moreActionsMenu");
  expect(languageStart).toBeGreaterThanOrEqual(0);
  expect(moreStart).toBeGreaterThan(languageStart);

  const languageMenu = panelActions.slice(languageStart, moreStart);
  const moreActionsMenu = panelActions.slice(moreStart);
  expect(languageMenu.match(/\bMenu\s*\{/g) ?? []).toHaveLength(1);
  expect(languageMenu).toContain(
    'panelActionLabel(title: store.copy.languageMenuTitle, symbol: "globe")',
  );
  expect(languageMenu).toContain("store.selectLocale(.zhHans)");
  expect(languageMenu).toContain("store.selectLocale(.zhHant)");
  expect(languageMenu).toContain("store.selectLocale(.en)");
  expect(moreActionsMenu.match(/\bMenu\s*\{/g) ?? []).toHaveLength(1);
  expect(moreActionsMenu).not.toContain("store.selectLocale(");
  expect(panelActions).toContain("@State private var menuCopy: QuotaCopy");
  expect(panelActions).toContain(".onChange(of: store.copy)");
  expect(moreActionsMenu).toContain("Button(menuCopy.openStatusMenuAction)");
  expect(moreActionsMenu).toContain("Button(menuCopy.toggleCapsuleAction)");
  expect(moreActionsMenu).toContain("Button(menuCopy.userGuideAction)");
  expect(moreActionsMenu).toContain("Button(menuCopy.contactAuthorTitle)");
  expect(moreActionsMenu).toContain("Button(menuCopy.aboutFeedbackTitle)");
  expect(moreActionsMenu).toContain("Label(menuCopy.quitAction, systemImage: \"power\")");
  expect(moreActionsMenu).not.toContain("Button(store.copy.");
  expect(moreActionsMenu).not.toContain("Label(store.copy.quitAction");
});
