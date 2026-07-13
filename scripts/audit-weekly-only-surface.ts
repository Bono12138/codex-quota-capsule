import { readdirSync, readFileSync, statSync } from "node:fs";
import { relative, resolve } from "node:path";

const roots = [
  "README.md",
  "README.zh-CN.md",
  "README.en.md",
  "INSTALL.md",
  "Sources/QuotaCapsuleCore",
  "Sources/QuotaCapsuleMac",
  "packages/core/src",
  "packages/source-codex/src",
  "apps/desktop/src",
  "docs/product",
  "docs/distribution",
];
const explicitExclusions = new Set([
  "Sources/QuotaCapsuleCore/WeeklyHistoryMigration.swift",
]);
const files = roots.flatMap(collectCurrentFiles).filter((file) => !explicitExclusions.has(file));
const forbidden = /5\s*小时|5\s*小時|5-hour|\b5h\b|shortWindow|short_window|short window|短窗口|等待新的/g;
const retiredProductCopy = /\bSafe\b|\bWatch\b|\bDanger\b|\bUnknown\b|daily[- ]budget|today's sustainable|今天的可持续|今天可持续|今日预算|今日可用预算|最近周速度区间/g;
const publicNarrativeFiles = new Set([
  "README.md",
  "README.zh-CN.md",
  "README.en.md",
  "INSTALL.md",
  "docs/product/brief.md",
  "docs/product/mvp-scope.md",
  "docs/product/visual-design-direction.md",
  "docs/distribution/public-launch-materials.md",
  "docs/distribution/launch-video-production-brief.md",
  "docs/distribution/launch-video-materials-requirements.md",
]);
const failures: string[] = [];

for (const file of files) {
  const text = readFileSync(resolve(process.cwd(), file), "utf8");
  text.split("\n").forEach((line, index) => {
    if (forbidden.test(line)) failures.push(`${file}:${index + 1}: ${line.trim()}`);
    forbidden.lastIndex = 0;
    if (publicNarrativeFiles.has(file) && retiredProductCopy.test(line)) {
      failures.push(`${file}:${index + 1}: retired product copy: ${line.trim()}`);
    }
    retiredProductCopy.lastIndex = 0;
  });
}

function collectCurrentFiles(entry: string): string[] {
  const absolute = resolve(process.cwd(), entry);
  if (!statSync(absolute).isDirectory()) return [entry];
  return readdirSync(absolute).flatMap((name) => {
    const child = resolve(absolute, name);
    if (statSync(child).isDirectory()) return collectCurrentFiles(relative(process.cwd(), child));
    return /\.(md|swift|ts|tsx)$/.test(name) && !/\.test\.(ts|tsx)$/.test(name)
      ? [relative(process.cwd(), child)]
      : [];
  });
}

if (failures.length) {
  console.error(`Weekly Only surface audit failed with ${failures.length} forbidden references:\n${failures.join("\n")}`);
  process.exit(1);
}

console.log(`Weekly Only surface audit passed (${files.length} current-release files).`);
