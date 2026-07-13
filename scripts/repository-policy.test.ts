import { describe, expect, it } from "vitest";
import {
  auditForecastDocumentation,
  auditMarkdownLinks,
  auditReleaseEvidence,
  auditReleaseMetadata,
  auditRepository,
  type RepositoryFile,
} from "./repository-policy";

describe("repository policy", () => {
  it("rejects legacy development channel text", () => {
    expect(auditRepository([
      textFile("package.json", '{"scripts":{"mac:run:dev":"./script/build_and_run.sh"}}'),
    ])).toContainEqual(expect.objectContaining({
      path: "package.json",
      rule: "legacy-dev-channel",
    }));
  });

  it("rejects a personal absolute path without printing its value", () => {
    const findings = auditRepository([
      textFile("README.md", "/Users/private-name/project"),
    ]);

    expect(findings).toContainEqual(expect.objectContaining({
      path: "README.md",
      rule: "personal-path",
    }));
    expect(JSON.stringify(findings)).not.toContain("private-name");
  });

  it("accepts the public beta identity", () => {
    expect(auditRepository([
      textFile("INSTALL.md", "Install Quota Capsule Beta from the public GitHub release."),
    ])).toEqual([]);
  });

  it("rejects credential-like filenames without reading binary content", () => {
    expect(auditRepository([
      { path: "config/private-key.pem", text: null },
    ])).toContainEqual(expect.objectContaining({
      path: "config/private-key.pem",
      rule: "credential-file",
    }));
  });

  it("rejects fixed six-hour calibration and hidden five-percent reserve rules", () => {
    const findings = auditRepository([
      textFile("docs/product/brief.md", "积累 6 小时有效数据后给出判断，并在重置时保留 5%"),
    ]);

    expect(findings.map((item) => item.rule)).toEqual(expect.arrayContaining([
      "fixed-calibration-gate",
      "hidden-budget-reserve",
    ]));
  });

  it("requires the maintained methodology to document the full adaptive contract", () => {
    const findings = auditForecastDocumentation([
      textFile("docs/product/forecast-methodology.md", "Weekly forecast"),
    ]);

    expect(findings).toContainEqual(expect.objectContaining({
      path: "docs/product/forecast-methodology.md",
      rule: "forecast-documentation",
    }));
  });

  it("rejects mismatched package, app, bundle, and tag versions", () => {
    const findings = auditReleaseMetadata([
      textFile("package.json", '{"version":"0.3.0"}'),
      textFile("script/build_and_run.sh", 'APP_VERSION="${QUOTA_CAPSULE_VERSION:-0.2.0}"\nBUNDLE_NAME="${QUOTA_CAPSULE_BUNDLE_NAME:-Quota Capsule Old}"\nBUNDLE_ID="${QUOTA_CAPSULE_BUNDLE_ID:-com.example.old}"'),
      textFile("script/package_macos.sh", 'BUNDLE_NAME="${QUOTA_CAPSULE_BUNDLE_NAME:-Quota Capsule Beta}"'),
    ], "v0.2.0-beta.1");

    expect(findings.map((item) => item.rule)).toEqual(expect.arrayContaining([
      "release-version-mismatch",
      "release-tag-mismatch",
      "release-bundle-mismatch",
    ]));
  });

  it("rejects broken internal Markdown links", () => {
    const findings = auditMarkdownLinks([
      textFile("README.md", "[missing](docs/missing.md)"),
      textFile("docs/README.md", "# Docs"),
    ]);

    expect(findings).toContainEqual(expect.objectContaining({
      path: "README.md",
      rule: "broken-document-link",
    }));
  });

  it("requires a complete release evidence record", () => {
    const findings = auditReleaseEvidence([
      textFile("CHANGELOG.md", "# Changelog"),
      textFile("docs/product/acceptance-criteria.md", "# Acceptance"),
      textFile("docs/operations/release-checklist.md", "# Checklist"),
    ]);

    expect(findings).toContainEqual(expect.objectContaining({
      rule: "missing-release-evidence",
    }));
  });
});

function textFile(path: string, text: string): RepositoryFile {
  return { path, text };
}
