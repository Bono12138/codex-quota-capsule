import { createHash } from "node:crypto";
import { existsSync, mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { afterEach, describe, expect, it } from "vitest";

const roots: string[] = [];
const script = resolve(process.cwd(), "script/retire_legacy_dev.sh");

afterEach(() => {
  for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true });
});

describe("legacy Dev retirement", () => {
  it("dry-run reports legacy paths without moving them", () => {
    const fixture = makeFixture(true);
    const result = run(fixture, "--dry-run");

    expect(result.status).toBe(0);
    expect(result.stdout).toContain("would archive legacy application");
    expect(result.stdout).toContain("would archive legacy data");
    expect(existsSync(fixture.app)).toBe(true);
    expect(existsSync(fixture.data)).toBe(true);
  });

  it("apply refuses to run without a verified archive", () => {
    const fixture = makeFixture(false);
    const result = run(fixture, "--apply");

    expect(result.status).toBe(2);
    expect(result.stderr).toContain("verified retirement archive is required");
    expect(existsSync(fixture.app)).toBe(true);
    expect(existsSync(fixture.data)).toBe(true);
  });

  it("apply moves legacy artifacts after checksum verification", () => {
    const fixture = makeFixture(true);
    const result = run(fixture, "--apply");

    expect(result.status).toBe(0);
    expect(existsSync(fixture.app)).toBe(false);
    expect(existsSync(fixture.data)).toBe(false);
    expect(existsSync(join(fixture.archive, "retired-artifacts", "Quota Capsule Dev Local.app"))).toBe(true);
    expect(existsSync(join(fixture.archive, "retired-artifacts", "Quota Capsule Dev Local"))).toBe(true);
  });
});

function makeFixture(withVerifiedArchive: boolean) {
  const root = mkdtempSync(join(tmpdir(), "quota-capsule-retirement-"));
  roots.push(root);
  const archive = join(root, "archive");
  const app = join(root, "Quota Capsule Dev Local.app");
  const data = join(root, "Quota Capsule Dev Local");
  mkdirSync(archive, { recursive: true });
  mkdirSync(app, { recursive: true });
  mkdirSync(data, { recursive: true });
  writeFileSync(join(app, "app.txt"), "legacy app", "utf8");
  writeFileSync(join(data, "history.txt"), "legacy history", "utf8");
  if (withVerifiedArchive) {
    const manifest = "verified fixture\n";
    writeFileSync(join(archive, "MANIFEST.md"), manifest, "utf8");
    const digest = createHash("sha256").update(manifest).digest("hex");
    writeFileSync(join(archive, "SHA256SUMS"), `${digest}  ./MANIFEST.md\n`, "utf8");
  }
  return { root, archive, app, data };
}

function run(fixture: ReturnType<typeof makeFixture>, mode: "--dry-run" | "--apply") {
  return spawnSync(script, [mode], {
    encoding: "utf8",
    env: {
      ...process.env,
      QUOTA_CAPSULE_ARCHIVE_DIR: fixture.archive,
      QUOTA_CAPSULE_LEGACY_APP: fixture.app,
      QUOTA_CAPSULE_LEGACY_DATA: fixture.data,
      QUOTA_CAPSULE_SKIP_PROCESS: "1",
    },
  });
}
