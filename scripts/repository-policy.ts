import { execFileSync } from "node:child_process";
import { basename, extname, resolve } from "node:path";
import { readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";

export type RepositoryFile = {
  path: string;
  text: string | null;
};

export type PolicyFinding = {
  path: string;
  rule: string;
  message: string;
};

const credentialFilePatterns = [
  /^\.env($|\.)/i,
  /\.(pem|p12|pfx|key)$/i,
  /^id_(rsa|ed25519)$/i,
  /cookie/i,
  /auth.*\.json$/i,
];

const secretPatterns = [
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
  /\bsk-proj-[A-Za-z0-9_-]{20,}\b/,
  /\bsk-[A-Za-z0-9_-]{20,}\b/,
  /\bgithub_pat_[A-Za-z0-9_]{20,}\b/,
  /\bghp_[A-Za-z0-9]{20,}\b/,
  /\bAKIA[0-9A-Z]{16}\b/,
  /\bOPENAI_API_KEY\s*=/i,
  /"(?:access|refresh)_token"\s*:\s*"[^"]{8,}"/i,
];

const legacyDevPatterns = [
  /Quota Capsule Dev Local/,
  /QuotaCapsuleDevLocal/,
  /com\.bono\.quota-capsule\.dev/,
  /QUOTA_CAPSULE_DEV_/,
  /mac:(?:run|package):dev/,
  /case\s+development/,
];

const binaryExtensions = new Set([
  ".gif", ".icns", ".jpeg", ".jpg", ".pdf", ".png", ".sqlite", ".zip",
]);

const generatedPathPatterns = [
  /(^|\/)(?:dist|node_modules|\.build|artifacts)(\/|$)/,
  /\.sqlite(?:-shm|-wal)?$/,
  /\.app(\/|$)/,
  /(^|\/)local-state(\/|$)/,
];

export function auditRepository(files: RepositoryFile[]): PolicyFinding[] {
  const findings: PolicyFinding[] = [];
  for (const file of files) {
    const normalizedPath = file.path.replaceAll("\\", "/");
    const name = basename(normalizedPath);

    if (credentialFilePatterns.some((pattern) => pattern.test(name))) {
      findings.push(finding(normalizedPath, "credential-file", "credential-like filename is not allowed"));
    }
    if (generatedPathPatterns.some((pattern) => pattern.test(normalizedPath))) {
      findings.push(finding(normalizedPath, "generated-output", "generated or local runtime output is tracked"));
    }
    const text = file.text;
    if (text === null) continue;

    if (secretPatterns.some((pattern) => pattern.test(text))) {
      findings.push(finding(normalizedPath, "secret-pattern", "credential-like content is not allowed"));
    }
    if (!allowsPolicyFixtures(normalizedPath)
      && /\/Users\/(?!example(?:\/|$))[A-Za-z0-9._-]+\//.test(text)) {
      findings.push(finding(normalizedPath, "personal-path", "a personal absolute filesystem path is not allowed"));
    }
    if (!allowsLegacyHistory(normalizedPath)
      && !allowsPolicyFixtures(normalizedPath)
      && legacyDevPatterns.some((pattern) => pattern.test(text))) {
      findings.push(finding(normalizedPath, "legacy-dev-channel", "legacy Dev channel text is not allowed in active files"));
    }
    if (!allowsLegacyHistory(normalizedPath)
      && !allowsPolicyFixtures(normalizedPath)
      && /(?:public[- ]repo[- ](?:staging|sync)|public staging|private working tree)/i.test(text)) {
      findings.push(finding(normalizedPath, "split-repository-workflow", "copy-based repository split text is not allowed in active files"));
    }
  }
  return findings;
}

function allowsPolicyFixtures(path: string): boolean {
  return path === "scripts/repository-policy.ts"
    || path === "scripts/repository-policy.test.ts"
    || path === "scripts/single-channel.test.ts";
}

export function trackedRepositoryFiles(root = process.cwd()): RepositoryFile[] {
  const output = execFileSync("git", ["ls-files", "-z"], {
    cwd: root,
    encoding: "utf8",
  });
  return output.split("\0").filter(Boolean).map((path) => {
    const absolutePath = resolve(root, path);
    const extension = extname(path).toLowerCase();
    if (binaryExtensions.has(extension) || statSync(absolutePath).size > 1_000_000) {
      return { path, text: null };
    }
    return { path, text: readFileSync(absolutePath, "utf8") };
  });
}

function allowsLegacyHistory(path: string): boolean {
  return path.startsWith("docs/superpowers/")
    || path === "docs/decisions/0004-release-channels-and-repository-split.md"
    || path === "docs/decisions/0005-version-management-and-release-flow.md"
    || path === "docs/operations/legacy-dev-retirement.md"
    || path === "script/retire_legacy_dev.sh"
    || path === "scripts/legacy-retirement.test.ts";
}

function finding(path: string, rule: string, message: string): PolicyFinding {
  return { path, rule, message };
}

function runCLI(): void {
  const findings = auditRepository(trackedRepositoryFiles());
  if (findings.length === 0) {
    console.log("Repository policy audit passed.");
    return;
  }
  for (const item of findings) {
    console.error(`${item.rule}: ${item.path} - ${item.message}`);
  }
  process.exitCode = 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  runCLI();
}
