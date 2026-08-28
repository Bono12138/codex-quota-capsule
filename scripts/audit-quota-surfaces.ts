import { readdirSync, readFileSync, statSync } from "node:fs";
import { relative, resolve } from "node:path";

import { ambiguousResetCopyReason, retiredProductCopyReason } from "./weekly-only-copy-rules";

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
const files = roots.flatMap(collectCurrentFiles);
const forbidden = /shortWindow|short_window|short window|短窗口|等待新的/i;
const failures: string[] = [];

for (const file of files) {
  const text = readFileSync(resolve(process.cwd(), file), "utf8");
  text.split("\n").forEach((line, index) => {
    if (forbidden.test(line)) failures.push(`${file}:${index + 1}: ${line.trim()}`);
    const resetReason = ambiguousResetCopyReason(line);
    if (resetReason) failures.push(`${file}:${index + 1}: ${resetReason}: ${line.trim()}`);
    if (file.endsWith(".md")) {
      const reason = retiredProductCopyReason(line);
      if (reason) failures.push(`${file}:${index + 1}: ${reason}: ${line.trim()}`);
    }
  });
}

for (const file of [
  "Sources/QuotaCapsuleCore/WeeklyRunwayPredictor.swift",
  "packages/core/src/prediction.ts",
]) {
  const text = readFileSync(resolve(process.cwd(), file), "utf8");
  if (/fiveHourWindow|five_hour|5\s*小时|5\s*小時|5-hour/i.test(text)) {
    failures.push(file + ": five-hour quota must not influence weekly forecasting");
  }
}

for (const file of [
  "Sources/QuotaCapsuleMac/CapsuleViews.swift",
  "apps/desktop/src/main.tsx",
]) {
  const text = readFileSync(resolve(process.cwd(), file), "utf8");
  if (!/fiveHour|five-hour|5\s*小时/i.test(text)) {
    failures.push(file + ": current UI must support a real five-hour quota reading");
  }
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
  console.error("Quota surface audit failed with " + failures.length + " issues:\n" + failures.join("\n"));
  process.exit(1);
}

console.log("Quota surface audit passed (" + files.length + " current-release files).");
