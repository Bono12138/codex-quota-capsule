import { describe, expect, it } from "vitest";
import { parseCodexRateLimits } from "../src";

describe("parseCodexRateLimits", () => {
  it("ignores short candidates and accepts only a true weekly duration", () => {
    const fetchedAt = new Date(1_788_270_000_000);
    const parsed = parseCodexRateLimits(
      {
        rateLimits: {
          primary: { usedPercent: 18, windowDurationMins: 300, resetsAt: 1_788_271_414 },
          secondary: { usedPercent: 41, windowDurationMins: 10_080, resetsAt: 1_788_299_735 },
        },
      },
      { fetchedAt },
    );

    expect(parsed.sourceStatus).toBe("ok");
    expect(parsed).not.toHaveProperty("shortWindow");
    expect(parsed.weeklyWindow?.windowMinutes).toBe(10_080);

    const dailyOnly = parseCodexRateLimits(
      { rateLimits: { primary: { usedPercent: 18, windowDurationMins: 1_440, resetsAt: 1_788_299_735 } } },
      { fetchedAt },
    );
    expect(dailyOnly.sourceStatus).toBe("error");
  });

  it("maps app-server windows by duration instead of primary order", () => {
    const parsed = parseCodexRateLimits(
      {
        rateLimits: {
          primary: {
            usedPercent: 41,
            windowDurationMins: 10080,
            resetsAt: 1_788_299_735,
          },
          secondary: {
            usedPercent: 17,
            windowDurationMins: 300,
            resetsAt: 1_788_271_414,
          },
        },
      },
      {
        fetchedAt: new Date(1_788_270_000_000),
      },
    );

    expect(parsed.provider).toBe("codex");
    expect(parsed.sourceStatus).toBe("ok");
    expect(parsed).not.toHaveProperty("shortWindow");
    expect(parsed.weeklyWindow?.label).toBe("weekly");
    expect(parsed.weeklyWindow?.usedPercent).toBe(41);
  });

  it("returns an error snapshot when no usable windows are present", () => {
    const parsed = parseCodexRateLimits(
      { rateLimits: {} },
      {
        fetchedAt: new Date(1_788_270_000_000),
      },
    );

    expect(parsed.sourceStatus).toBe("error");
    expect(parsed).not.toHaveProperty("shortWindow");
    expect(parsed.errorMessage).toContain("rateLimits");
  });

  it("treats a weekly-only response as the complete successful source result", () => {
    const parsed = parseCodexRateLimits(
      {
        rateLimits: {
          primary: {
            usedPercent: 41,
            windowDurationMins: 10080,
            resetsAt: 1_788_299_735,
          },
        },
      },
      {
        fetchedAt: new Date(1_788_270_000_000),
      },
    );

    expect(parsed.sourceStatus).toBe("ok");
    expect(parsed).not.toHaveProperty("shortWindow");
    expect(parsed.weeklyWindow?.label).toBe("weekly");
    expect(parsed.weeklyWindow?.usedPercent).toBe(41);
    expect(parsed.errorMessage).toBeUndefined();
  });

  it.each([
    { usedPercent: -1, windowDurationMins: 10_080, resetsAt: 1_788_299_735 },
    { usedPercent: 101, windowDurationMins: 10_080, resetsAt: 1_788_299_735 },
    { usedPercent: 1, windowDurationMins: 0, resetsAt: 1_788_299_735 },
    { usedPercent: 1, windowDurationMins: Number.POSITIVE_INFINITY, resetsAt: 1_788_299_735 },
    { usedPercent: 1, windowDurationMins: 10_080, resetsAt: Number.NaN },
  ])("rejects unsafe numeric windows: %j", (window) => {
    const parsed = parseCodexRateLimits(
      { rateLimits: { primary: window } },
      { fetchedAt: new Date(1_788_270_000_000) },
    );

    expect(parsed.sourceStatus).toBe("error");
    expect(parsed).not.toHaveProperty("shortWindow");
  });

  it("preserves fractional usage for prediction math", () => {
    const parsed = parseCodexRateLimits(
      {
        rateLimits: {
          primary: { usedPercent: 0.9, windowDurationMins: 10_080, resetsAt: 1_788_299_735 },
        },
      },
      { fetchedAt: new Date(1_788_270_000_000) },
    );

    expect(parsed.weeklyWindow?.usedPercent).toBe(0.9);
    expect(parsed.weeklyWindow?.remainingPercent).toBe(99.1);
  });

  it("parses reset credits without exposing raw identity or descriptions", () => {
    const fetchedAt = new Date(1_788_270_000_000);
    const parsed = parseCodexRateLimits(
      {
        rateLimits: {
          primary: { usedPercent: 18, windowDurationMins: 10_080, resetsAt: 1_788_299_735 },
        },
        rateLimitResetCredits: {
          availableCount: 3,
          credits: [
            {
              id: "fake-credit-a",
              resetType: "codexRateLimits",
              status: "available",
              grantedAt: 1_788_183_600,
              expiresAt: 1_788_356_400,
              title: "  Full reset  ",
              description: "must be ignored",
            },
            {
              id: "fake-credit-b",
              resetType: "codexRateLimits",
              status: "unknown",
              grantedAt: 1_788_226_800,
              expiresAt: null,
              title: null,
              description: null,
            },
          ],
        },
      },
      { fetchedAt },
    );

    expect(parsed.resetCreditBank?.availableCount).toBe(3);
    expect(parsed.resetCreditBank?.detailState).toBe("capped");
    expect(parsed.resetCreditBank?.credits?.[0].fingerprint).toMatch(/^[0-9a-f]{64}$/);
    expect(parsed.resetCreditBank?.credits?.[0].fingerprint).not.toBe("fake-credit-a");
    expect(parsed.resetCreditBank?.credits?.[0].title).toBe("Full reset");
    expect(parsed.resetCreditBank?.credits?.[0]).not.toHaveProperty("id");
    expect(parsed.resetCreditBank?.credits?.[0]).not.toHaveProperty("description");
    expect(parsed.resetCreditBank?.credits?.[1].expiresAt).toBeNull();
  });

  it("distinguishes count-only, empty, missing, and invalid reset credit details", () => {
    const fetchedAt = new Date(1_788_270_000_000);
    const weekly = {
      primary: { usedPercent: 18, windowDurationMins: 10_080, resetsAt: 1_788_299_735 },
    };

    const countOnly = parseCodexRateLimits(
      { rateLimits: weekly, rateLimitResetCredits: { availableCount: 2, credits: null } },
      { fetchedAt },
    );
    const empty = parseCodexRateLimits(
      { rateLimits: weekly, rateLimitResetCredits: { availableCount: 0, credits: [] } },
      { fetchedAt },
    );
    const missing = parseCodexRateLimits({ rateLimits: weekly }, { fetchedAt });
    const partiallyInvalid = parseCodexRateLimits(
      {
        rateLimits: weekly,
        rateLimitResetCredits: {
          availableCount: 3,
          credits: [
            { id: "fake-good", resetType: "codexRateLimits", status: "available", grantedAt: null, expiresAt: 1_788_356_400 },
            { id: "fake-bad-grant", resetType: "codexRateLimits", status: "available", grantedAt: "bad", expiresAt: 1_788_356_400 },
            { id: "fake-bad-expiry", resetType: "codexRateLimits", status: "available", grantedAt: null, expiresAt: -1 },
          ],
        },
      },
      { fetchedAt },
    );

    expect(countOnly.resetCreditBank).toMatchObject({ availableCount: 2, credits: null, detailState: "countOnly" });
    expect(empty.resetCreditBank).toMatchObject({ availableCount: 0, credits: [], detailState: "complete" });
    expect(missing.resetCreditBank).toBeUndefined();
    expect(partiallyInvalid.resetCreditBank?.credits).toHaveLength(1);
    expect(partiallyInvalid.resetCreditBank?.credits?.[0].grantedAt).toBeNull();
    expect(partiallyInvalid.resetCreditBank?.credits?.[0].grantTimeSource).toBe("unknown");
    expect(partiallyInvalid.resetCreditBank?.detailState).toBe("capped");
  });
});
