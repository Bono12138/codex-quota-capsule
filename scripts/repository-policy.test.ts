import { describe, expect, it } from "vitest";
import { auditRepository, type RepositoryFile } from "./repository-policy";

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
});

function textFile(path: string, text: string): RepositoryFile {
  return { path, text };
}
