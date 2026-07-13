import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const root = process.cwd();

describe("single public Beta channel", () => {
  it("has no Dev package commands", () => {
    const packageJson = JSON.parse(read("package.json")) as {
      scripts: Record<string, string>;
    };

    expect(packageJson.scripts["mac:run:dev"]).toBeUndefined();
    expect(packageJson.scripts["mac:package:dev"]).toBeUndefined();
    expect(packageJson.scripts["mac:run:internal-test"]).toBeUndefined();
    expect(packageJson.scripts["mac:package:internal-test"]).toBeUndefined();
    expect(packageJson.scripts["mac:install:internal-test"]).toBeUndefined();
    expect(packageJson.scripts["mac:run"]).toBe("./script/build_and_run.sh");
    expect(packageJson.scripts["mac:package"]).toBe("./script/package_macos.sh");
    expect(packageJson.scripts["mac:install"]).toBe("./script/build_and_run.sh --install");
  });

  it("contains only the public Beta app identity", () => {
    const sources = [
      "Sources/QuotaCapsuleMac/AppConfiguration.swift",
      "script/build_and_run.sh",
      "script/package_macos.sh",
    ].map(read).join("\n");
    const forbidden = [
      "case development",
      "Quota Capsule Dev Local",
      "com.bono.quota-capsule.dev",
      "QUOTA_CAPSULE_DEV_",
      "QuotaCapsuleDevLocal",
    ];

    for (const text of forbidden) expect(sources).not.toContain(text);
    expect(sources).toContain("Quota Capsule Beta");
    expect(sources).toContain("com.bono.quota-capsule.beta");
    expect(sources).toContain("QuotaCapsuleBeta");
  });

  it("does not branch build behavior on a release channel", () => {
    expect(read("script/build_and_run.sh")).not.toContain("QUOTA_CAPSULE_CHANNEL");
    expect(read("script/package_macos.sh")).not.toContain("QUOTA_CAPSULE_CHANNEL");
  });
});

function read(path: string): string {
  return readFileSync(resolve(root, path), "utf8");
}
