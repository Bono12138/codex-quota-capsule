import { readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join, relative, resolve } from "node:path";

type Finding = {
  path: string;
  rule: "personal-path";
};

const personalPathPatterns = [
  /\/Users\/(?!\[redacted\](?:\/|\0|\s|$))[A-Za-z0-9._-]+(?:\/|\0|\s|$)/,
  /\/home\/[A-Za-z0-9._-]+(?:\/|\0|\s|$)/,
  /[A-Za-z]:\\Users\\[A-Za-z0-9._-]+(?:\\|\0|\s|$)/,
  /\/private\/var\/folders\//,
];

export function auditReleaseArtifact(target: string): Finding[] {
  const root = resolve(target);
  return artifactFiles(root).flatMap((path) => {
    const content = readFileSync(path).toString("latin1");
    if (!personalPathPatterns.some((pattern) => pattern.test(content))) return [];
    return [{
      path: statSync(root).isDirectory() ? relative(root, path) || basename(path) : basename(path),
      rule: "personal-path" as const,
    }];
  });
}

function artifactFiles(path: string): string[] {
  const metadata = statSync(path);
  if (metadata.isFile()) return [path];
  if (!metadata.isDirectory()) return [];
  return readdirSync(path, { withFileTypes: true }).flatMap((entry) => {
    if (entry.isSymbolicLink()) return [];
    return artifactFiles(join(path, entry.name));
  });
}

function runCLI(): void {
  const target = process.argv[2];
  if (!target) {
    console.error("usage: audit-release-artifact <file-or-app-bundle>");
    process.exitCode = 2;
    return;
  }
  const findings = auditReleaseArtifact(target);
  if (findings.length === 0) {
    console.log("Release artifact privacy audit passed.");
    return;
  }
  for (const finding of findings) {
    console.error(`${finding.rule}: ${finding.path} contains a private local filesystem path`);
  }
  process.exitCode = 1;
}

runCLI();
