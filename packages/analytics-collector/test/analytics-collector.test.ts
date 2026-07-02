import { describe, expect, it } from "vitest";
import { validateAnalyticsEvent } from "../src/index";

const baseEvent = {
  event_id: "evt_1",
  event_name: "app_launched",
  event_time: 1_788_270_000,
  install_id_hash: "abcdef0123456789",
  app_version: "0.1.0",
  schema_version: 1,
  locale: "zh-Hans",
  macos_major_version: 15,
  arch: "arm64",
  analytics_consent_version: "2026-07-01-v1",
  consent: "granted",
  language: "zh-Hans",
  properties: {
    collection_tier: "essential_diagnostics",
  },
};

describe("analytics collector validation", () => {
  it("accepts registered essential diagnostic events", () => {
    expect(validateAnalyticsEvent(baseEvent).ok).toBe(true);
  });

  it("rejects sensitive field names", () => {
    expect(
      validateAnalyticsEvent({
        ...baseEvent,
        properties: {
          collection_tier: "product_improvement",
          project_name: "private-repo",
        },
      }),
    ).toMatchObject({ ok: false });
  });

  it("rejects nested sensitive field names", () => {
    expect(
      validateAnalyticsEvent({
        ...baseEvent,
        properties: {
          collection_tier: "product_improvement",
          context: {
            window_title: "private editor",
          },
        },
      }),
    ).toMatchObject({ ok: false });
  });

  it("accepts registered product usage events", () => {
    expect(
      validateAnalyticsEvent({
        ...baseEvent,
        event_name: "quota_state_sampled",
        properties: {
          collection_tier: "product_improvement",
          panel_state: "collapsed",
          width_bucket: "medium",
          short_used_percent: "12",
          short_elapsed_percent: "34",
          projected_remaining_at_reset_percent: "65",
          weekly_used_percent: "18",
        },
      }).ok,
    ).toBe(true);
  });

  it("accepts settings and menu interaction events", () => {
    expect(
      validateAnalyticsEvent({
        ...baseEvent,
        event_name: "settings_opened",
        surface: "feedback",
        properties: {
          collection_tier: "product_improvement",
        },
      }).ok,
    ).toBe(true);
    expect(
      validateAnalyticsEvent({
        ...baseEvent,
        event_name: "menu_opened",
        surface: "menu_bar",
        properties: {
          collection_tier: "product_improvement",
        },
      }).ok,
    ).toBe(true);
  });

  it("accepts feedback nudge events", () => {
    expect(
      validateAnalyticsEvent({
        ...baseEvent,
        event_name: "feedback_nudge_shown",
        surface: "feedback",
        properties: {
          collection_tier: "product_improvement",
          trigger: "expanded_count",
        },
      }).ok,
    ).toBe(true);
    expect(
      validateAnalyticsEvent({
        ...baseEvent,
        event_name: "feedback_nudge_decision",
        surface: "feedback",
        properties: {
          collection_tier: "product_improvement",
          decision: "copy_codex_prompt",
        },
      }).ok,
    ).toBe(true);
  });

  it("rejects unknown event names", () => {
    expect(
      validateAnalyticsEvent({
        ...baseEvent,
        event_name: "raw_terminal_command",
      }),
    ).toMatchObject({ ok: false });
  });
});
