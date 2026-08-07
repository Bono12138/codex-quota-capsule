import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

describe("release artifact privacy audit", () => {
  it("rejects a personal macOS build path without echoing the username", () => {
    const root = mkdtempSync(join(tmpdir(), "quota-release-privacy-"));
    const binary = join(root, "QuotaCapsuleBeta");
    writeFileSync(binary, Buffer.from("prefix\0/Users/private-name/project/.build/release\0suffix"));

    const result = runAudit(binary);

    expect(result.status).toBe(1);
    expect(result.output).toContain("personal-path");
    expect(result.output).not.toContain("private-name");
  });

  it("rejects a standalone macOS home directory without a trailing slash", () => {
    const root = mkdtempSync(join(tmpdir(), "quota-release-privacy-"));
    const binary = join(root, "QuotaCapsuleBeta");
    writeFileSync(binary, Buffer.from("/Users/private-name\0"));

    expect(runAudit(binary).status).toBe(1);
  });

  it("allows redacted paths and approved public contact details", () => {
    const root = mkdtempSync(join(tmpdir(), "quota-release-privacy-"));
    const binary = join(root, "QuotaCapsuleBeta");
    writeFileSync(binary, Buffer.from([
      "/Users/[redacted]",
      String.raw`/Users/[^/\s]+`,
      "mmz1218bono@gmail.com",
      "https://x.com/starlightsz0",
      "huotuichang439",
    ].join("\0")));

    const result = runAudit(binary);

    expect(result).toEqual({ status: 0, output: "Release artifact privacy audit passed.\n" });
  });
});

function runAudit(path: string): { status: number; output: string } {
  try {
    const output = execFileSync(process.execPath, ["--import", "tsx", "scripts/audit-release-artifact.ts", path], {
      cwd: process.cwd(),
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    return { status: 0, output };
  } catch (error) {
    const failure = error as { status?: number; stdout?: Buffer | string; stderr?: Buffer | string };
    return {
      status: failure.status ?? 1,
      output: `${failure.stdout ?? ""}${failure.stderr ?? ""}`,
    };
  }
}
