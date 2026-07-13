import { execFileSync } from "node:child_process";
import { basename, extname, posix, resolve } from "node:path";
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

export function auditReleaseMetadata(files: RepositoryFile[], tag?: string): PolicyFinding[] {
  const findings: PolicyFinding[] = [];
  const packageText = textAt(files, "package.json");
  const buildScript = textAt(files, "script/build_and_run.sh");
  const packageScript = textAt(files, "script/package_macos.sh");
  let version: string | null = null;
  try {
    const value = packageText ? JSON.parse(packageText) as { version?: unknown } : {};
    version = typeof value.version === "string" ? value.version : null;
  } catch {
    version = null;
  }
  const appVersion = captureDefault(buildScript, /APP_VERSION="\$\{QUOTA_CAPSULE_VERSION:-([^}]+)\}"/);
  const buildBundle = captureDefault(buildScript, /BUNDLE_NAME="\$\{QUOTA_CAPSULE_BUNDLE_NAME:-([^}]+)\}"/);
  const packageBundle = captureDefault(packageScript, /BUNDLE_NAME="\$\{QUOTA_CAPSULE_BUNDLE_NAME:-([^}]+)\}"/);
  const bundleID = captureDefault(buildScript, /BUNDLE_ID="\$\{QUOTA_CAPSULE_BUNDLE_ID:-([^}]+)\}"/);

  if (!version || appVersion !== version) {
    findings.push(finding("script/build_and_run.sh", "release-version-mismatch", "package and app versions must match"));
  }
  if (buildBundle !== "Quota Capsule Beta"
    || packageBundle !== "Quota Capsule Beta"
    || buildBundle !== packageBundle
    || bundleID !== "com.bono.quota-capsule.beta") {
    findings.push(finding("script/build_and_run.sh", "release-bundle-mismatch", "the supported Beta name and bundle identifier must match"));
  }
  if (tag && (!version || !new RegExp(`^v${escapeRegExp(version)}-beta\\.\\d+$`).test(tag))) {
    findings.push(finding("package.json", "release-tag-mismatch", "release tag does not match the package version"));
  }
  return findings;
}

export function auditMarkdownLinks(files: RepositoryFile[]): PolicyFinding[] {
  const findings: PolicyFinding[] = [];
  const paths = new Set(files.map((file) => file.path.replaceAll("\\", "/")));
  for (const file of files) {
    const filePath = file.path.replaceAll("\\", "/");
    if (!filePath.endsWith(".md") || file.text === null) continue;
    for (const match of file.text.matchAll(/!?\[[^\]]*\]\(([^)]+)\)/g)) {
      let target = match[1].trim();
      if (target.startsWith("<") && target.endsWith(">")) target = target.slice(1, -1);
      if (/^(?:https?:|mailto:|app:|data:|#)/i.test(target)) continue;
      target = target.split("#", 1)[0].split("?", 1)[0];
      if (!target) continue;
      try {
        target = decodeURIComponent(target);
      } catch {
        findings.push(finding(filePath, "broken-document-link", "internal Markdown link is malformed"));
        continue;
      }
      const candidate = target.startsWith("/")
        ? posix.normalize(target.slice(1))
        : posix.normalize(posix.join(posix.dirname(filePath), target));
      const resolved = paths.has(candidate)
        || paths.has(`${candidate}/README.md`)
        || (candidate.endsWith("/") && paths.has(`${candidate}README.md`));
      if (!resolved) {
        findings.push(finding(filePath, "broken-document-link", "internal Markdown link target is missing"));
      }
    }
  }
  return findings;
}

export function auditReleaseEvidence(files: RepositoryFile[]): PolicyFinding[] {
  const findings: PolicyFinding[] = [];
  const requiredPaths = [
    "CHANGELOG.md",
    "docs/product/acceptance-criteria.md",
    "docs/operations/release-checklist.md",
  ];
  for (const path of requiredPaths) {
    if (!files.some((file) => file.path.replaceAll("\\", "/") === path)) {
      findings.push(finding(path, "missing-release-evidence", "required release record is missing"));
    }
  }
  const evidence = files.find((file) => /^docs\/operations\/release-evidence\/v[^/]+\.md$/.test(file.path.replaceAll("\\", "/")))?.text;
  const requiredSections = [
    /Automated verification/i,
    /Installed app verification/i,
    /Code review/i,
    /Pull request/i,
    /Release status/i,
  ];
  if (!evidence || requiredSections.some((section) => !section.test(evidence))) {
    findings.push(finding("docs/operations/release-evidence", "missing-release-evidence", "release evidence is missing required verification sections"));
  }
  return findings;
}

function allowsPolicyFixtures(path: string): boolean {
  return path === "scripts/repository-policy.ts"
    || path === "scripts/repository-policy.test.ts"
    || path === "scripts/single-channel.test.ts";
}

function textAt(files: RepositoryFile[], path: string): string | null {
  return files.find((file) => file.path.replaceAll("\\", "/") === path)?.text ?? null;
}

function captureDefault(text: string | null, pattern: RegExp): string | null {
  return text?.match(pattern)?.[1] ?? null;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
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
  const tag = process.env.GITHUB_REF_TYPE === "tag" ? process.env.GITHUB_REF_NAME : undefined;
  const findings = [
    ...auditRepository(files),
    ...auditForecastDocumentation(files),
    ...auditReleaseMetadata(files, tag),
    ...auditMarkdownLinks(files),
    ...auditReleaseEvidence(files),
  ];
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
