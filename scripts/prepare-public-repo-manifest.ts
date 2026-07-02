import { cp, mkdir, readdir, readFile, rm, stat, writeFile } from "node:fs/promises";
import { basename, dirname, extname, join, relative, resolve, sep } from "node:path";
import { argv, cwd, exit } from "node:process";

const root = resolve(cwd());
const outputArg = argv.find((arg) => arg.startsWith("--out="));
const outputDir = resolve(root, outputArg?.slice("--out=".length) ?? "artifacts/public-repo-staging");

const publicPaths = [
  "AGENTS.md",
  "CONTRIBUTING.md",
  "INSTALL.md",
  "LICENSE",
  "Package.swift",
  "README.md",
  "README.en.md",
  "README.zh-CN.md",
  ".editorconfig",
  ".gitignore",
  "package.json",
  "package-lock.json",
  "tsconfig.base.json",
  "vitest.config.ts",
  ".github/ISSUE_TEMPLATE/adapter-request.md",
  ".github/ISSUE_TEMPLATE/bug-report.md",
  ".github/ISSUE_TEMPLATE/feature-request.md",
  ".github/ISSUE_TEMPLATE/install-help.md",
  ".github/labels.yml",
  ".github/workflows/ci.yml",
  "Sources/QuotaCapsuleCore",
  "Sources/QuotaCapsuleCoreSpec",
  "Sources/QuotaCapsuleMac",
  "apps/desktop",
  "packages/core",
  "packages/source-codex",
  "packages/analytics-collector",
  "scripts",
  "script",
  "docs/decisions/0001-repo-boundary.md",
  "docs/decisions/0002-codex-first-agent-extensible.md",
  "docs/decisions/0003-distribution-and-surface-plan.md",
  "docs/decisions/0004-release-channels-and-repository-split.md",
  "docs/product/brief.md",
  "docs/product/mvp-scope.md",
  "docs/product/acceptance-criteria.md",
  "docs/product/feature-roadmap.md",
  "docs/product/visual-design-direction.md",
  "docs/product/bug-triage-and-release-blockers.md",
  "docs/product/analytics-collector.md",
  "docs/assets/douyin-qr-scan.png",
  "docs/distribution/codex-assisted-distribution-strategy.md",
  "docs/distribution/public-launch-materials.md",
  "docs/distribution/public-repo-file-manifest.md",
  "docs/research/data-source-probe.md",
];

const privatePaths = [
  "docs/project-handoff-for-next-thread.md",
  "docs/product/strategy-and-commercialization.md",
  "docs/product/product-ops-feedback-and-copy.md",
  "docs/product/development-plan.md",
  "docs/research/competitors",
];

const ignoredPathSegments = new Set([
  ".git",
  ".build",
  "node_modules",
  "dist",
  "local-state",
  "artifacts",
  ".DS_Store",
]);

const highRiskFileNames = [
  /^\.env($|\.)/,
  /\.pem$/i,
  /\.p12$/i,
  /\.pfx$/i,
  /\.key$/i,
  /^id_rsa$/i,
  /^id_ed25519$/i,
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
  /"access_token"\s*:\s*"[^"]{8,}"/i,
  /"refresh_token"\s*:\s*"[^"]{8,}"/i,
  /\/Users\/(?!example\/)[A-Za-z0-9._-]+\//,
];

const binaryExtensions = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".icns",
  ".pdf",
  ".zip",
  ".app",
  ".sqlite",
]);

type Finding = {
  level: "error" | "warning";
  path: string;
  message: string;
};

const findings: Finding[] = [];

await rm(outputDir, { recursive: true, force: true });
await mkdir(outputDir, { recursive: true });

for (const sourcePath of publicPaths) {
  const source = resolve(root, sourcePath);
  const destination = resolve(outputDir, sourcePath);
  if (!(await exists(source))) {
    findings.push({ level: "error", path: sourcePath, message: "listed public path is missing" });
    continue;
  }
  await mkdir(dirname(destination), { recursive: true });
  await cp(source, destination, {
    recursive: true,
    filter: (src) => shouldCopy(src),
  });
}

for (const privatePath of privatePaths) {
  if (await exists(resolve(outputDir, privatePath))) {
    findings.push({ level: "error", path: privatePath, message: "private-only path was copied into public staging" });
  }
}

await scanPublicStaging(outputDir);

const reportLines = [
  "# Public Repository Staging Audit",
  "",
  `Generated: ${new Date().toISOString()}`,
  `Output: ${relative(root, outputDir) || "."}`,
  "",
  "## Copied Paths",
  "",
  ...publicPaths.map((path) => `- ${path}`),
  "",
  "## Findings",
  "",
];

if (findings.length === 0) {
  reportLines.push("- No blocking findings.");
} else {
  for (const finding of findings) {
    reportLines.push(`- ${finding.level.toUpperCase()}: ${finding.path} - ${finding.message}`);
  }
}

await writeFile(join(outputDir, "PUBLIC_STAGING_AUDIT.md"), `${reportLines.join("\n")}\n`, "utf8");

const errors = findings.filter((finding) => finding.level === "error");
console.log(`Public staging written to ${relative(root, outputDir)}`);
console.log(`Audit report: ${relative(root, join(outputDir, "PUBLIC_STAGING_AUDIT.md"))}`);
if (errors.length > 0) {
  console.error(`Public staging audit failed with ${errors.length} blocking finding(s).`);
  exit(1);
}

async function scanPublicStaging(directory: string) {
  for (const filePath of await listFiles(directory)) {
    const rel = relative(outputDir, filePath);
    if (highRiskFileNames.some((pattern) => pattern.test(basename(filePath)))) {
      findings.push({ level: "error", path: rel, message: "high-risk credential-like filename" });
      continue;
    }

    const extension = extname(filePath).toLowerCase();
    if (binaryExtensions.has(extension)) {
      continue;
    }

    const fileStat = await stat(filePath);
    if (fileStat.size > 1_000_000) {
      findings.push({ level: "warning", path: rel, message: "large text file skipped during secret pattern scan" });
      continue;
    }

    const text = await readFile(filePath, "utf8");
    const matched = secretPatterns.find((pattern) => pattern.test(text));
    if (matched) {
      findings.push({ level: "error", path: rel, message: `matched secret pattern ${matched}` });
    }
  }
}

async function listFiles(directory: string): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (shouldSkipRelative(relative(outputDir, path))) {
      continue;
    }
    if (entry.isDirectory()) {
      files.push(...await listFiles(path));
    } else if (entry.isFile()) {
      files.push(path);
    }
  }
  return files;
}

function shouldCopy(sourcePath: string): boolean {
  const rel = relative(root, sourcePath);
  return !shouldSkipRelative(rel);
}

function shouldSkipRelative(path: string): boolean {
  return path.split(sep).some((segment) => ignoredPathSegments.has(segment));
}

async function exists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}
