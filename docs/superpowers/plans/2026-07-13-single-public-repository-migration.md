# Single Public Repository Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire the Dev channel and private/public copy workflow, preserve useful legacy information safely, correct GitHub attribution to `Bono12138`, and leave one public repository plus one installed Beta app as the only active product lineage.

**Architecture:** Archive-before-delete protects all legacy refs and private-only documents. A tracked-tree repository policy audit replaces allowlist copying, while the native app and shell scripts collapse to one Beta identity. Public history is rewritten once, after a verified Git bundle exists, to remove the erroneous `lililovesivy` co-author footer.

**Tech Stack:** Git/GitHub CLI, TypeScript/Vitest, Bash, Swift 6, GitHub Actions, macOS codesign and Spotlight.

## Global Constraints

- The only source of truth is `https://github.com/Bono12138/codex-quota-capsule`.
- Git author and committer identity is `Bono12138 <Bono12138@users.noreply.github.com>`.
- No destructive cleanup occurs before archive checksums and Git bundle restoration pass.
- Only `Quota Capsule Beta.app` may remain installed or running.
- Secrets, private paths, raw local databases, authenticated responses, and private strategy notes never enter public Git history.
- Routine work uses `codex/*` branches and reviewed pull requests; no direct routine pushes to `main`.
- Every release is built from the exact reviewed public `main` commit.

---

### Task 1: Build And Verify The Legacy Archive

**Files:**
- Create outside repo: `~/Documents/Quota Capsule Archive/2026-07-13-dev-retirement/MANIFEST.md`
- Create outside repo: `~/Documents/Quota Capsule Archive/2026-07-13-dev-retirement/legacy-repository.bundle`
- Create outside repo: `~/Documents/Quota Capsule Archive/2026-07-13-dev-retirement/SHA256SUMS`
- Create outside repo: `~/Documents/Quota Capsule Archive/2026-07-13-dev-retirement/private-documents/`

**Interfaces:**
- Consumes: all local and remote refs plus private-only paths listed by the former public-staging script.
- Produces: a restorable Git bundle and checksummed private archive used by every later destructive task.

- [ ] **Step 1: Record the complete inventory without changing refs**

Run:

```bash
git fetch --prune origin
git for-each-ref --format='%(refname) %(objectname)' refs/heads refs/remotes/origin refs/tags
git worktree list --porcelain
mdfind 'kMDItemFSName == "Quota Capsule*.app"c'
pgrep -laf 'QuotaCapsule|Quota Capsule' || true
```

Expected: the report includes public `main`, legacy remote branches, local Weekly Only branches/worktrees, the Beta app, and no unrecorded second repository.

- [ ] **Step 2: Export private-only documents from the last containing ref**

Use `git show origin/codex/p0-stability-i18n:<path>` for:

```text
docs/project-handoff-for-next-thread.md
docs/product/strategy-and-commercialization.md
docs/product/product-ops-feedback-and-copy.md
docs/product/development-plan.md
docs/research/competitors/
```

Write exports only under `private-documents/`. Record each source ref and destination in `MANIFEST.md`; do not copy those raw files into the public repository.

- [ ] **Step 3: Create the full Git bundle**

Run:

```bash
git bundle create "$HOME/Documents/Quota Capsule Archive/2026-07-13-dev-retirement/legacy-repository.bundle" --all
git bundle verify "$HOME/Documents/Quota Capsule Archive/2026-07-13-dev-retirement/legacy-repository.bundle"
```

Expected: `The bundle records a complete history` and all required refs are listed.

- [ ] **Step 4: Generate and verify checksums**

Run SHA-256 over every archived file, save relative paths in `SHA256SUMS`, then run:

```bash
cd "$HOME/Documents/Quota Capsule Archive/2026-07-13-dev-retirement"
shasum -a 256 -c SHA256SUMS
```

Expected: every line ends with `OK`.

- [ ] **Step 5: Prove restoration in a temporary directory**

Run:

```bash
restore_dir="$(mktemp -d)"
git clone "$HOME/Documents/Quota Capsule Archive/2026-07-13-dev-retirement/legacy-repository.bundle" "$restore_dir/repository"
git -C "$restore_dir/repository" fsck --full
rm -rf "$restore_dir"
```

Expected: clone succeeds and `git fsck` reports no corruption.

### Task 2: Correct Public Git Attribution

**Files:**
- Modify operationally: public `main` and tag `v0.2.0-beta.1`
- Modify local config: `.git/config` (not committed)
- Archive: original ref SHAs in `MANIFEST.md`

**Interfaces:**
- Consumes: verified Task 1 bundle.
- Produces: public main history whose reachable commits and merge message do not credit `lililovesivy`.

- [ ] **Step 1: Lock the local identity**

Run:

```bash
git config user.name Bono12138
git config user.email Bono12138@users.noreply.github.com
```

Expected: both local values match exactly.

- [ ] **Step 2: Verify the reason for the false contributor label**

Run:

```bash
git show -s --format=fuller 8457112162b5d06db97b40d11280a3e9ab6c5707
git show -s --format=%B 8457112162b5d06db97b40d11280a3e9ab6c5707
```

Expected: Git author maps to `Bono12138`, and the only `lililovesivy` attribution reachable from `main` is the `Co-authored-by` footer.

- [ ] **Step 3: Create a corrected Weekly Only commit locally**

Starting from parent `8c140131494d5bcb613de9199a3f911fa55d4932`, create a commit with the exact tree of `8457112`, author/committer `Bono12138`, the same subject/body, and the `Co-authored-by` footer removed. Verify:

```bash
test "$(git rev-parse corrected-main^{tree})" = "$(git rev-parse 8457112^{tree})"
git log corrected-main --format='%an <%ae>%n%b' | rg 'lililovesivy' && exit 1 || true
```

Expected: tree hashes match and no reachable attribution contains `lililovesivy`.

- [ ] **Step 4: Rebase the approved design commit onto corrected main**

Rebase `codex/single-public-repo-adaptive-forecast` with `--onto corrected-main 8457112`. Verify its author and committer are both `Bono12138`.

- [ ] **Step 5: Update public main and the beta tag atomically enough to recover**

Record old refs in the manifest, temporarily disable release automation if necessary, push corrected `main` with `--force-with-lease=<old-sha>`, recreate `v0.2.0-beta.1` at corrected main, and update the existing GitHub release target. Never use an unconstrained `--force`.

- [ ] **Step 6: Verify GitHub attribution**

Run:

```bash
gh api repos/Bono12138/codex-quota-capsule/contributors --jq '.[] | [.login,.contributions] | @tsv'
gh api repos/Bono12138/codex-quota-capsule/commits --paginate --jq '.[].commit.message' | rg 'lililovesivy' && exit 1 || true
```

Expected: only `Bono12138` appears as a code contributor and no reachable default-branch commit message contains the wrong identity.

### Task 3: Replace Copy-Based Public Staging With A Tracked-Tree Audit

**Files:**
- Create: `scripts/repository-policy.ts`
- Create: `scripts/repository-policy.test.ts`
- Delete: `scripts/prepare-public-repo-manifest.ts`
- Delete: `scripts/prepare-public-repo-manifest.test.ts`
- Modify: `package.json`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: `auditRepository(files: RepositoryFile[]): PolicyFinding[]` and CLI `npm run audit:repository`.

- [ ] **Step 1: Write the failing policy tests**

Test exact behavior:

```ts
it("rejects legacy development channel text", () => {
  expect(auditRepository([{ path: "package.json", text: '"mac:run:dev"' }]))
    .toContainEqual(expect.objectContaining({ rule: "legacy-dev-channel" }));
});

it("rejects a personal absolute path without printing its value", () => {
  const findings = auditRepository([{ path: "README.md", text: "/Users/example/project" }]);
  expect(findings[0]).toMatchObject({ path: "README.md", rule: "personal-path" });
  expect(JSON.stringify(findings)).not.toContain("private-name");
});

it("accepts the public beta identity", () => {
  expect(auditRepository([{ path: "INSTALL.md", text: "Quota Capsule Beta" }])).toEqual([]);
});
```

- [ ] **Step 2: Run RED**

Run: `npx vitest run scripts/repository-policy.test.ts`

Expected: FAIL because `repository-policy.ts` does not exist.

- [ ] **Step 3: Implement the minimal scanner**

Define:

```ts
export type RepositoryFile = { path: string; text: string | null };
export type PolicyFinding = { path: string; rule: string; message: string };
export function auditRepository(files: RepositoryFile[]): PolicyFinding[];
```

Rules cover credential-like filenames, secret tokens, absolute personal paths, private repo URLs, tracked build/database/log output, Dev identifiers, public-staging/sync workflow text outside historical ADRs/specs, and forbidden 5-hour user-facing copy.

- [ ] **Step 4: Run GREEN and the full TypeScript suite**

Run:

```bash
npx vitest run scripts/repository-policy.test.ts
npm test
```

Expected: targeted and full suites pass.

- [ ] **Step 5: Wire CI and commit**

Replace `public:prepare` with `audit:repository`, update CI, delete copy-based scripts, run `npm run audit:repository`, and commit as `Replace public staging with repository audit`.

### Task 4: Collapse Native Configuration To One Beta Channel

**Files:**
- Create: `scripts/single-channel.test.ts`
- Modify: `Sources/QuotaCapsuleMac/AppConfiguration.swift`
- Modify: `Sources/QuotaCapsuleMac/QuotaStore.swift`
- Modify: `Sources/QuotaCapsuleMac/FeedbackSupport.swift`
- Modify: `Sources/QuotaCapsuleMac/QuotaHistoryStore.swift`

**Interfaces:**
- Produces: `AppConfiguration.current()` with one fixed Beta identity and public-safe optional analytics endpoint.

- [ ] **Step 1: Write a failing source-policy test**

Read the tracked source files and assert they contain none of:

```ts
const forbidden = [
  "case development",
  "Quota Capsule Dev Local",
  "com.bono.quota-capsule.dev",
  "QUOTA_CAPSULE_DEV_",
  "QuotaCapsuleDevLocal",
];
```

Also assert `AppConfiguration.swift` contains `Quota Capsule Beta`, `com.bono.quota-capsule.beta`, and the public issues URL.

- [ ] **Step 2: Run RED**

Run: `npx vitest run scripts/single-channel.test.ts`

Expected: FAIL on the current Development case.

- [ ] **Step 3: Remove the Development channel**

Keep `ReleaseChannel.internalTest` only if downstream telemetry requires the enum; otherwise remove `ReleaseChannel` and make configuration constants explicit. Preserve the existing Beta bundle identifier and data directory so installed history is not lost.

- [ ] **Step 4: Run GREEN and Swift verification**

Run:

```bash
npx vitest run scripts/single-channel.test.ts
swift test
swift run QuotaCapsuleCoreSpec
```

Expected: all pass.

- [ ] **Step 5: Commit**

Commit as `Retire the Dev application channel`.

### Task 5: Make Build And Install Single-Instance Safe

**Files:**
- Modify: `script/build_and_run.sh`
- Modify: `script/package_macos.sh`
- Create: `script/retire_legacy_dev.sh`
- Modify: `package.json`
- Test: `scripts/single-channel.test.ts`

**Interfaces:**
- Produces: one Beta build/install path and `retire_legacy_dev.sh --dry-run|--apply`.

- [ ] **Step 1: Extend the failing tests**

Assert:

```ts
expect(packageJson.scripts["mac:run:dev"]).toBeUndefined();
expect(packageJson.scripts["mac:package:dev"]).toBeUndefined();
expect(runScript).not.toContain("development|dev");
expect(packageScript).not.toContain("development|dev");
```

Invoke `QUOTA_CAPSULE_CHANNEL=development ./script/build_and_run.sh` and expect exit code `2` with a safe error.

- [ ] **Step 2: Run RED**

Run: `npx vitest run scripts/single-channel.test.ts`

Expected: FAIL because Dev commands and branches still exist.

- [ ] **Step 3: Implement one Beta build path and guarded legacy retirement**

The retirement script must terminate `QuotaCapsuleDevLocal`, move any legacy app and data directory into the verified local archive, and refuse `--apply` when the archive manifest/checksum marker is missing. It must never delete Beta history.

- [ ] **Step 4: Run GREEN and package verification**

Run:

```bash
npx vitest run scripts/single-channel.test.ts
npm run mac:package
codesign --verify --deep --strict --verbose=2 "dist/internal-test/Quota Capsule Beta.app"
```

Expected: all pass; no Dev bundle is produced.

- [ ] **Step 5: Commit**

Commit as `Enforce one installed Quota Capsule app`.

### Task 6: Replace Obsolete Governance Documentation

**Files:**
- Create: `docs/README.md`
- Create: `docs/decisions/0006-single-public-repository-and-app.md`
- Create: `docs/operations/release-checklist.md`
- Create: `docs/operations/legacy-dev-retirement.md`
- Create: `CHANGELOG.md`
- Modify: `AGENTS.md`
- Modify: `CONTRIBUTING.md`
- Modify: `INSTALL.md`
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `README.zh-CN.md`
- Modify: `docs/decisions/0004-release-channels-and-repository-split.md`
- Modify: `docs/decisions/0005-version-management-and-release-flow.md`
- Modify/delete: obsolete distribution and public-staging documentation.

**Interfaces:**
- Produces: one current public workflow and clearly labeled historical ADRs.

- [ ] **Step 1: Add a failing documentation policy assertion**

Extend `repository-policy.test.ts` so active docs fail when they contain `private working tree`, `public staging`, `mac:run:dev`, or Dev bundle identifiers. Allow those terms only in superseded ADR history and the retirement record.

- [ ] **Step 2: Run RED**

Run: `npx vitest run scripts/repository-policy.test.ts`

Expected: FAIL on active README/install/contribution documents.

- [ ] **Step 3: Write the maintained documentation set**

The docs index labels each file `current`, `historical`, or `superseded`. ADR 0006 records the one-repo/one-app decision. ADRs 0004/0005 retain history but begin with `Status: Superseded by ADR 0006`. Release checklist requires attribution, privacy, tests, one-app state, commit fingerprint, and real-use observation.

- [ ] **Step 4: Run GREEN and link checks**

Run `npm run audit:repository`, `rg` for obsolete active copy, and a Markdown-link checker over tracked Markdown files.

Expected: no blocking findings or broken relative links.

- [ ] **Step 5: Commit**

Commit as `Document the single public repository workflow`.

### Task 7: Merge, Protect, Retire, And Reclone

**Files:**
- Remote: branch ruleset, merged PR, deleted legacy branches.
- Local: canonical `~/Desktop/codex-quota-capsule` fresh clone.

**Interfaces:**
- Consumes: Tasks 1-6 complete and green.
- Produces: one clean public repository clone and no active Dev lineage.

- [ ] **Step 1: Run the complete pre-PR suite**

Run:

```bash
npm test
npm run lint
npm run build
npm run audit:repository
swift test
swift run QuotaCapsuleCoreSpec
swift build --product QuotaCapsuleMac
git diff --check
```

Expected: all pass from the committed branch.

- [ ] **Step 2: Push and open a PR authored by Bono12138**

Verify every branch commit author first, push, open the PR, and ensure CI passes before merge.

- [ ] **Step 3: Configure and verify `main` protection**

Require pull requests and CI checks; block force pushes and branch deletion after the one-time attribution correction is complete. Record the ruleset URL/ID in the release checklist.

- [ ] **Step 4: Delete obsolete refs only after merge**

Delete remote legacy branches `agent/quota-capsule-runtime-fixes`, `codex/quota-capsule-runtime-fixes`, and `codex/p0-stability-i18n`; remove merged local branches and linked worktrees after confirming all commits remain in the archive bundle.

- [ ] **Step 5: Retire Dev artifacts safely**

Run `script/retire_legacy_dev.sh --dry-run`, inspect, then `--apply`. Verify no Dev app/process/data remains outside the archive.

- [ ] **Step 6: Replace the old local repository with a fresh public clone**

Move the retired clone into the archive area, clone public `main` to `~/Desktop/codex-quota-capsule`, and rerun the complete suite. Do not remove the retired clone until the new clone and Git bundle both pass.

- [ ] **Step 7: Verify final provenance**

Expected:

```text
origin = public Bono12138 repository
branch = main
working tree = clean
contributors = Bono12138 only
installed apps = Quota Capsule Beta.app only
running processes = QuotaCapsuleBeta only
```
