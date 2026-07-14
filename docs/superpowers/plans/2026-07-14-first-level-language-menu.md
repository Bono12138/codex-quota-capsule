# First-Level Language Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make interface language discoverable from the floating panel even when the user cannot read the active locale, without restoring nested-menu flicker.

**Architecture:** Keep `PanelQuickActionsView` as the action-layout owner and add a sibling, one-layer `languageMenu` beside the existing `moreActionsMenu`. Locale mutation continues through `QuotaStore.selectLocale`; no data-source, history, prediction, analytics, or reset-credit behavior changes. Source-architecture and locale-copy tests define the menu boundary before implementation.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Swift Testing, TypeScript, Vitest, Bash packaging, GitHub Actions.

## Global Constraints

- The release target remains `v0.3.2-beta.1`; no tag or GitHub Release exists until merged-main installation passes.
- The first-level language control always includes the globe symbol and the English word `Language`.
- The choices are direct actions named `简体中文`, `繁體中文`, and `English`.
- `languageMenu` and `moreActionsMenu` are siblings; neither menu may contain another `Menu`.
- The existing adaptive layout wraps at narrow widths; no fixed fourth-column width is introduced.
- No quota-source, history, prediction, analytics, privacy, or reset-credit behavior changes.
- Implementation follows red-green-refactor and must be verified in the installed `/Applications/Quota Capsule Beta.app` built from exact merged `main`.

---

### Task 1: Lock the menu architecture and locale copy with failing tests

**Files:**
- Modify: `scripts/panel-menu-stability.test.ts`
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklyDisplayModelTests.swift`

**Interfaces:**
- Consumes: `PanelQuickActionsView`, `QuotaCopy.languageMenuTitle`.
- Produces: a source-architecture contract for sibling `languageMenu` and `moreActionsMenu`, plus a three-locale discoverability contract.

- [x] **Step 1: Replace the panel menu regression with sibling-menu assertions**

Use the following Vitest body after extracting `panelActions`:

```ts
expect(panelActions.match(/\bMenu\s*\{/g) ?? []).toHaveLength(2);
expect(panelActions).toContain("languageMenu");

const languageStart = panelActions.indexOf("private var languageMenu");
const moreStart = panelActions.indexOf("private var moreActionsMenu");
expect(languageStart).toBeGreaterThanOrEqual(0);
expect(moreStart).toBeGreaterThan(languageStart);

const languageMenu = panelActions.slice(languageStart, moreStart);
const moreActionsMenu = panelActions.slice(moreStart);
expect(languageMenu.match(/\bMenu\s*\{/g) ?? []).toHaveLength(1);
expect(languageMenu).toContain('panelActionLabel(title: store.copy.languageMenuTitle, symbol: "globe")');
expect(languageMenu).toContain("store.selectLocale(.zhHans)");
expect(languageMenu).toContain("store.selectLocale(.zhHant)");
expect(languageMenu).toContain("store.selectLocale(.en)");
expect(moreActionsMenu.match(/\bMenu\s*\{/g) ?? []).toHaveLength(1);
expect(moreActionsMenu).not.toContain("store.selectLocale(");
```

- [x] **Step 2: Add a three-locale title test**

Add this Swift Testing case to the existing weekly display copy suite:

```swift
@Test("panel language entry stays discoverable in every locale")
func panelLanguageEntryStaysDiscoverable() {
    for locale in [QuotaLocale.zhHans, .zhHant, .en] {
        let copy = QuotaCopy(locale: locale)
        #expect(copy.languageMenuTitle.contains("Language"))
    }
}
```

- [x] **Step 3: Run focused tests and confirm RED**

Run:

```bash
npx vitest run scripts/panel-menu-stability.test.ts
swift test --filter panelLanguageEntryStaysDiscoverable
```

Expected: the Vitest case fails because `PanelQuickActionsView` has only one menu and no `languageMenu`; the locale-copy case passes because the existing labels already include `Language`.

- [x] **Step 4: Commit the failing regression**

```bash
git add scripts/panel-menu-stability.test.ts Tests/QuotaCapsuleCoreTests/WeeklyDisplayModelTests.swift
git commit -m "Test first-level language discovery"
```

---

### Task 2: Add the first-level language menu and remove duplicate language actions

**Files:**
- Modify: `Sources/QuotaCapsuleMac/CapsuleViews.swift:603-708`
- Modify: `Sources/QuotaCapsuleCore/QuotaLocale.swift:747-775`
- Modify: `Sources/QuotaCapsuleCore/QuotaLocale.swift:1512-1517`

**Interfaces:**
- Consumes: `QuotaStore.selectLocale(_:)`, `QuotaCopy.languageMenuTitle`, existing adaptive `primaryActions` layout.
- Produces: `private var languageMenu: some View`, a peer of `moreActionsMenu`.

- [x] **Step 1: Insert the language control into `primaryActions`**

Place it between feedback and More actions:

```swift
        languageMenu
        moreActionsMenu
```

- [x] **Step 2: Implement the one-layer language menu**

Add immediately before `moreActionsMenu`:

```swift
    private var languageMenu: some View {
        Menu {
            Button("简体中文") {
                store.selectLocale(.zhHans)
            }
            Button("繁體中文") {
                store.selectLocale(.zhHant)
            }
            Button("English") {
                store.selectLocale(.en)
            }
        } label: {
            panelActionLabel(title: store.copy.languageMenuTitle, symbol: "globe")
        }
        .buttonStyle(.plain)
        .help(store.copy.languageMenuTitle)
    }
```

- [x] **Step 3: Delete the language section from `moreActionsMenu`**

Remove the complete `Section(store.copy.languageMenuTitle)` block and its three locale buttons. Keep all status, visibility, guide, author, about, and quit actions unchanged.

- [x] **Step 4: Update shipped three-locale feature and onboarding copy**

Change the relevant strings so each locale says that Language is first-level and More contains the remaining tools. Use these meanings exactly:

```text
zh-Hans: 展开面板直接提供刷新、反馈、Language / 语言和更多操作；引导、作者、关于和退出收在更多操作里。
zh-Hant: 展開面板直接提供重新整理、回饋、Language / 語言和更多操作；引導、作者、關於和退出收在更多操作裡。
en: The detail panel provides Refresh, Feedback, and Language directly; guide, author, about, and quit remain under More actions.
```

- [x] **Step 5: Run focused tests and confirm GREEN**

```bash
npx vitest run scripts/panel-menu-stability.test.ts
swift test --filter panelLanguageEntryStaysDiscoverable
swift build --product QuotaCapsuleMac
```

Expected: all focused tests pass and the macOS product builds.

- [x] **Step 6: Commit the implementation**

```bash
git add Sources/QuotaCapsuleMac/CapsuleViews.swift Sources/QuotaCapsuleCore/QuotaLocale.swift
git commit -m "Expose language in panel actions"
```

---

### Task 3: Align product contracts and release evidence

**Files:**
- Modify: `docs/product/acceptance-criteria.md`
- Modify: `docs/product/bug-triage-and-release-blockers.md`
- Modify: `docs/operations/release-evidence/v0.3.2-beta.1.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: the approved design and implemented panel hierarchy.
- Produces: current documentation that can be audited against the shipped UI.

- [x] **Step 1: Replace obsolete three-action and More-hosted-language rules**

The current acceptance rules must require four peer actions and state that Language is directly visible. Replace validation instructions that look for language inside More actions with instructions that open the first-level Language menu in all three locales.

- [x] **Step 2: Add the discoverability defect to the P1 release blockers**

Record that a language selector hidden behind locale-dependent copy blocks release because a user unable to read the active locale cannot recover.

- [x] **Step 3: Update release evidence and changelog**

Record that PR #20 removed the nested-menu flicker but the owner identified a remaining discoverability issue before tagging. State that `v0.3.2-beta.1` remains unreleased until the first-level language control passes installed-app acceptance.

- [x] **Step 4: Run document gates**

```bash
npm run audit:repository
npm run audit:weekly-only
git diff --check
```

Expected: all three commands pass.

- [x] **Step 5: Commit the aligned contract**

```bash
git add CHANGELOG.md docs/product/acceptance-criteria.md docs/product/bug-triage-and-release-blockers.md docs/operations/release-evidence/v0.3.2-beta.1.md
git commit -m "Document first-level language access"
```

---

### Task 4: Verify the branch candidate and installed interaction

**Files:**
- Verify: `/Applications/Quota Capsule Beta.app`
- Generate only ignored artifacts under: `local-state/audits/2026-07-14-first-level-language/`

**Interfaces:**
- Consumes: branch implementation and current local Codex app-server state.
- Produces: repeatable automated output plus installed-app accessibility evidence.

- [x] **Step 1: Run the complete gate with fail-fast semantics**

```bash
set -e
npm test
npm run build
npm run lint
npm run audit:repository
npm run audit:weekly-only
swift test
swift run QuotaCapsuleCoreSpec
swift build --product QuotaCapsuleMac
npm run mac:package
git diff --check
codesign --verify --deep --strict --verbose=2 "dist/beta/Quota Capsule Beta.app"
unzip -t "dist/beta/Quota-Capsule-Beta-macOS.zip"
```

Expected: 106 or more Node/Vitest tests, 90 or more Swift tests, both builds, all audits, signature verification, and archive integrity pass.

- [x] **Step 2: Install the branch candidate atomically**

```bash
npm run mac:install
plutil -p "/Applications/Quota Capsule Beta.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "/Applications/Quota Capsule Beta.app"
ps -p "$(pgrep -n -x QuotaCapsuleBeta)" -o pid=,command=
```

Expected: one process runs from `/Applications`, version is `0.3.2`, and the embedded commit/source-patch fingerprint matches the candidate.

- [x] **Step 3: Inspect all three locales and normal/narrow widths**

Use macOS accessibility inspection to verify the first-level globe/Language control is visible, exposes all three direct choices, and More actions contains no language choices. Repeat after selecting Simplified Chinese, Traditional Chinese, and English; resize to the minimum supported width and confirm adaptive wrapping remains readable.

- [x] **Step 4: Hold each menu across a real automatic read**

Keep Language open across one successful automatic-read interval, then repeat for More actions. Sample accessibility state continuously and record that the menu remains present, selectable, and single-layer before and after the data timestamp/countdown changes.

- [x] **Step 5: Commit only durable source evidence**

Update `docs/operations/release-evidence/v0.3.2-beta.1.md` with counts, duration, visible actions, installed commit, and result. Do not commit screenshots, raw authenticated responses, local paths, account data, or runtime databases.

---

### Task 5: Publish through protected main and release the exact merged build

**Files:**
- Publish: branch `codex/language-first-level`
- Release: `v0.3.2-beta.1`
- Artifact: `dist/beta/Quota-Capsule-Beta-macOS.zip`

**Interfaces:**
- Consumes: clean branch, installed acceptance evidence, required `node` and `macos-swift` checks.
- Produces: merged public source, prerelease tag, downloadable artifact, and one supported installed app.

- [ ] **Step 1: Push and open a ready PR**

The PR describes the accessibility root cause, the sibling-menu design, TDD evidence, installed interaction evidence, and why PR #20 alone was insufficient.

- [ ] **Step 2: Wait for required checks and squash-merge**

Require `node` and `macos-swift` to pass. Confirm every commit and the squash merge map only to GitHub user `Bono12138`.

- [ ] **Step 3: Re-run the full gate on exact merged `main`**

Pull protected `main`, run Task 4 Step 1 again, package and install again, and confirm `QuotaCapsuleGitCommit` equals the merged-main short hash with an empty source-patch fingerprint.

- [ ] **Step 4: Create and verify the prerelease**

Create tag `v0.3.2-beta.1`, wait for tag CI, publish a GitHub prerelease with the exact merged-main ZIP, and compare the local SHA-256 with the asset downloaded back from GitHub.

- [ ] **Step 5: Clean transient artifacts and report links**

Remove generated `dist/beta/Quota Capsule Beta.app` after the release ZIP is verified, retain only `/Applications/Quota Capsule Beta.app`, verify GitHub contributors still lists only `Bono12138`, and report the PR, release, competitor research, colleague brief, CI, checksum, and remaining honest limitations.
