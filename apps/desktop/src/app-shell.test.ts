import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

describe("desktop app shell", () => {
  it("declares an inline favicon so visual checks do not log a missing favicon request", () => {
    const html = readFileSync(resolve(__dirname, "../index.html"), "utf8");

    expect(html).toMatch(/<link rel="icon" href="data:image\/svg\+xml,/);
  });
});
