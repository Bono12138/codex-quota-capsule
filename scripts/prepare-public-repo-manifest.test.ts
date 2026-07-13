import { execFile } from "node:child_process";
import { access, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";
import { afterEach, describe, expect, test } from "vitest";

const execFileAsync = promisify(execFile);
const temporaryDirectories: string[] = [];

afterEach(async () => {
  await Promise.all(temporaryDirectories.splice(0).map((path) => rm(path, { recursive: true, force: true })));
});

describe("public repository staging", () => {
  test("contains every test and shared fixture required by the advertised checks", async () => {
    const root = resolve(process.cwd());
    const output = await mkdtemp(join(tmpdir(), "quota-capsule-public-"));
    temporaryDirectories.push(output);

    await execFileAsync(
      join(root, "node_modules/.bin/tsx"),
      [join(root, "scripts/prepare-public-repo-manifest.ts"), `--out=${output}`],
      { cwd: root }
    );

    const requiredPaths = [
      "Tests/QuotaCapsuleCoreTests/WeeklyDisplayModelTests.swift",
      "Tests/QuotaCapsuleCoreTests/WeeklyFixtureParityTests.swift",
      "Tests/QuotaCapsuleCoreTests/WeeklyHistoryMigrationTests.swift",
      "Tests/QuotaCapsuleCoreTests/WeeklyQualityEngineTests.swift",
      "Tests/QuotaCapsuleCoreTests/WeeklyRunwayPredictorTests.swift",
      "Tests/QuotaCapsuleCoreTests/WeeklySourceTests.swift",
      "fixtures/weekly-runway-cases.json",
    ];

    await expect(Promise.all(requiredPaths.map((path) => access(join(output, path))))).resolves.toBeDefined();
  });
});
