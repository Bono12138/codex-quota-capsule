import { describe, expect, it } from "vitest";
import { parseCodexRateLimits } from "../src";

describe("parseCodexRateLimits", () => {
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
        fetchedAt: new Date("2026-07-01T12:00:00+08:00"),
      },
    );

    expect(parsed.provider).toBe("codex");
    expect(parsed.sourceStatus).toBe("ok");
    expect(parsed.shortWindow?.label).toBe("5h");
    expect(parsed.shortWindow?.usedPercent).toBe(17);
    expect(parsed.shortWindow?.remainingPercent).toBe(83);
    expect(parsed.weeklyWindow?.label).toBe("weekly");
    expect(parsed.weeklyWindow?.usedPercent).toBe(41);
  });

  it("returns an error snapshot when no usable windows are present", () => {
    const parsed = parseCodexRateLimits(
      { rateLimits: {} },
      {
        fetchedAt: new Date("2026-07-01T12:00:00+08:00"),
      },
    );

    expect(parsed.sourceStatus).toBe("error");
    expect(parsed.shortWindow).toBeUndefined();
    expect(parsed.errorMessage).toContain("rateLimits");
  });

  it("treats a weekly-only response as an incomplete retryable snapshot", () => {
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
        fetchedAt: new Date("2026-07-01T12:00:00+08:00"),
      },
    );

    expect(parsed.sourceStatus).toBe("error");
    expect(parsed.shortWindow).toBeUndefined();
    expect(parsed.weeklyWindow?.label).toBe("weekly");
    expect(parsed.weeklyWindow?.usedPercent).toBe(41);
    expect(parsed.errorMessage).toContain("5-hour");
  });

  it.each([
    { usedPercent: -1, windowDurationMins: 300, resetsAt: 1_788_299_735 },
    { usedPercent: 101, windowDurationMins: 300, resetsAt: 1_788_299_735 },
    { usedPercent: 1, windowDurationMins: 0, resetsAt: 1_788_299_735 },
    { usedPercent: 1, windowDurationMins: Number.POSITIVE_INFINITY, resetsAt: 1_788_299_735 },
    { usedPercent: 1, windowDurationMins: 300, resetsAt: Number.NaN },
  ])("rejects unsafe numeric windows: %j", (window) => {
    const parsed = parseCodexRateLimits(
      { rateLimits: { primary: window } },
      { fetchedAt: new Date("2026-07-01T12:00:00+08:00") },
    );

    expect(parsed.sourceStatus).toBe("error");
    expect(parsed.shortWindow).toBeUndefined();
  });

  it("preserves fractional usage for prediction math", () => {
    const parsed = parseCodexRateLimits(
      {
        rateLimits: {
          primary: { usedPercent: 0.9, windowDurationMins: 300, resetsAt: 1_788_299_735 },
        },
      },
      { fetchedAt: new Date("2026-07-01T12:00:00+08:00") },
    );

    expect(parsed.shortWindow?.usedPercent).toBe(0.9);
    expect(parsed.shortWindow?.remainingPercent).toBe(99.1);
  });
});
