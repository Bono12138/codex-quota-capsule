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

const fixedCalibrationPatterns = [
  /积累\s*6\s*小时有效数据后/,
  /累積\s*6\s*小時有效資料後/,
  /minimumCoverage\s*=\s*6/i,
  /(?:collect|wait)[^\n]{0,40}6[- ]?hours?[^\n]{0,40}(?:before|until)/i,
];

const hiddenReservePatterns = [
  /保留\s*5%/,
  /5%\s+reserve\s+at\s+reset/i,
  /reservePercent\s*=\s*5/i,
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
    if (!allowsLegacyHistory(normalizedPath)
      && !allowsPolicyFixtures(normalizedPath)
      && fixedCalibrationPatterns.some((pattern) => pattern.test(text))) {
      findings.push(finding(normalizedPath, "fixed-calibration-gate", "a fixed six-hour forecast gate is not allowed"));
    }
    if (!allowsLegacyHistory(normalizedPath)
      && !allowsPolicyFixtures(normalizedPath)
      && hiddenReservePatterns.some((pattern) => pattern.test(text))) {
      findings.push(finding(normalizedPath, "hidden-budget-reserve", "a hidden five-percent budget reserve is not allowed"));
    }
  }
  return findings;
}

export function auditForecastDocumentation(files: RepositoryFile[]): PolicyFinding[] {
  const path = "docs/product/forecast-methodology.md";
  const document = files.find((file) => file.path.replaceAll("\\", "/") === path)?.text;
  const requiredConcepts = [
    /first valid reading/i,
    /±0\.5/,
    /cycle evidence/i,
    /recent evidence/i,
    /activity evidence/i,
    /historical prior/i,
    /confidence/i,
    /remaining\s*\/\s*hours to reset/i,
    /stale/i,
    /quota reset[^\n]{0,80}data read/i,
  ];
  if (document === null || document === undefined || requiredConcepts.some((pattern) => !pattern.test(document))) {
    return [finding(path, "forecast-documentation", "adaptive forecast methodology is missing required product contracts")];
  }
  return [];
}

function allowsPolicyFixtures(path: string): boolean {
  return path === "scripts/repository-policy.ts"
    || path === "scripts/repository-policy.test.ts"
    || path === "scripts/single-channel.test.ts";
}

export function trackedRepositoryFiles(root = process.cwd()): RepositoryFile[] {
  const output = execFileSync("git", ["ls-files", "-z", "--cached", "--others", "--exclude-standard"], {
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
  const files = trackedRepositoryFiles();
  const findings = [...auditRepository(files), ...auditForecastDocumentation(files)];
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
