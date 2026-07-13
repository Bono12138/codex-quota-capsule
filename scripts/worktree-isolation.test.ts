import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

describe("local probe worktree isolation", () => {
  for (const path of ["scripts/read-codex-rate-limits.ts", "scripts/run-codex-probe.ts"]) {
    it(`${path} imports the current checkout rather than a parent workspace`, () => {
      const source = readFileSync(resolve(process.cwd(), path), "utf8");

      expect(source).not.toMatch(/from\s+["']@quota-capsule\//);
      expect(source).toMatch(/from\s+["']\.\.\/packages\//);
    });
  }
});
