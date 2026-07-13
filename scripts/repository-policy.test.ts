import { describe, expect, it } from "vitest";
import { auditForecastDocumentation, auditRepository, type RepositoryFile } from "./repository-policy";

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
});

function textFile(path: string, text: string): RepositoryFile {
  return { path, text };
}
