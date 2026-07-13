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
    expect(parsed.shortWindow).toBeUndefined();
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
    expect(parsed.shortWindow).toBeUndefined();
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
    expect(parsed.shortWindow).toBeUndefined();
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
});
