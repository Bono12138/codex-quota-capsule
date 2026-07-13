import { describe, expect, it } from "vitest";
import { readCodexRateLimitsFromTransport, type CodexAppServerTransport } from "../src";

class FakeTransport implements CodexAppServerTransport {
  readonly sent: unknown[] = [];
  private readonly reads: unknown[];

  constructor(reads: unknown[]) {
    this.reads = reads;
  }

  send(payload: unknown): void {
    this.sent.push(payload);
  }

  async read(_timeoutMs?: number): Promise<unknown> {
    const next = this.reads.shift();
    if (!next) throw new Error("no fake response queued");
    return next;
  }
}

describe("readCodexRateLimitsFromTransport", () => {
  it("initializes app-server, skips notifications, reads rate limits, and parses the result", async () => {
    const transport = new FakeTransport([
      ...Array.from({ length: 75 }, (_, index) => ({
        jsonrpc: "2.0",
        method: "window/logMessage",
        params: { index },
      })),
      { jsonrpc: "2.0", id: 1, result: { capabilities: {} } },
      ...Array.from({ length: 75 }, (_, index) => ({
        jsonrpc: "2.0",
        method: "account/rateLimits/changed",
        params: { index },
      })),
      {
        jsonrpc: "2.0",
        id: 2,
        result: {
          rateLimits: {
            primary: { usedPercent: 62, windowDurationMins: 300, resetsAt: 1_788_271_414 },
            secondary: { usedPercent: 24, windowDurationMins: 10080, resetsAt: 1_788_299_735 },
          },
        },
      },
    ]);

    const snapshot = await readCodexRateLimitsFromTransport(transport, {
      fetchedAt: new Date(1_788_270_000_000),
    });

    expect(transport.sent).toEqual([
      {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          clientInfo: { name: "quota-capsule", title: "Quota Capsule", version: "0.0.0" },
          capabilities: {},
        },
      },
      { jsonrpc: "2.0", method: "initialized", params: {} },
      { jsonrpc: "2.0", id: 2, method: "account/rateLimits/read", params: {} },
    ]);
    expect(snapshot.sourceStatus).toBe("ok");
    expect(snapshot).not.toHaveProperty("shortWindow");
    expect(snapshot.weeklyWindow?.usedPercent).toBe(24);
  });

  it("returns an error snapshot when app-server returns an RPC error", async () => {
    const snapshot = await readCodexRateLimitsFromTransport(
      new FakeTransport([
        { jsonrpc: "2.0", id: 1, result: {} },
        { jsonrpc: "2.0", id: 2, error: { code: -32000, message: "not signed in" } },
      ]),
      { fetchedAt: new Date("2026-07-01T12:00:00+08:00") },
    );

    expect(snapshot.sourceStatus).toBe("error");
    expect(snapshot.errorMessage).toContain("not signed in");
  });

  it("returns an error snapshot when the app-server transport fails", async () => {
    const snapshot = await readCodexRateLimitsFromTransport(new FakeTransport([]), {
      fetchedAt: new Date("2026-07-01T12:00:00+08:00"),
    });

    expect(snapshot.sourceStatus).toBe("error");
    expect(snapshot.errorMessage).toContain("no fake response queued");
  });

  it("uses one overall deadline across unrelated notifications", async () => {
    const notifications = Array.from({ length: 20 }, (_, index) => ({
      jsonrpc: "2.0",
      method: "window/logMessage",
      params: { index },
    }));
    const transport: CodexAppServerTransport = {
      send() {},
      async read() {
        await new Promise((resolve) => setTimeout(resolve, 10));
        return notifications.shift() ?? { jsonrpc: "2.0", id: 2, result: { rateLimits: {} } };
      },
    };
    const startedAt = Date.now();
    const snapshot = await readCodexRateLimitsFromTransport(transport, {
      fetchedAt: new Date("2026-07-01T12:00:00+08:00"),
      timeoutMs: 50,
    });

    expect(snapshot.sourceStatus).toBe("error");
    expect(Date.now() - startedAt).toBeLessThan(150);
  });
});
