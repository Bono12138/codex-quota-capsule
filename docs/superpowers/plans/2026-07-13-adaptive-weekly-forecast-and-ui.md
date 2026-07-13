# Adaptive Weekly Forecast And UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fixed six-hour calibration gate with evidence-driven weekly forecasting that gives immediate preliminary value, exposes reset and data-refresh timing clearly, and becomes more precise as real usage evidence accumulates.

**Architecture:** Swift and TypeScript share fixture-driven behavior. Independent cycle, recent, transition, activity, and historical estimators emit bounded pace evidence with reliability scores; a robust weighted fusion produces a forecast interval and confidence explanation. Presentation consumes only the forecast/display model, never raw source data.

**Tech Stack:** Swift 6/Swift Testing/SwiftUI, TypeScript/Vitest, JSON parity fixtures, local SQLite history.

## Global Constraints

- Weekly Only: no 5-hour display, calculation, fallback, or copy.
- No fixed minimum six-hour coverage gate.
- The first valid weekly reading produces an honest preliminary result when reset metadata is valid.
- Quantized percentages are intervals, not exact continuous measurements.
- Stale or conflicting data cannot produce fresh reassurance.
- Next-24-hour budget is based on actual remaining time and has no hidden five-percent reserve.
- Reset confirmation remains three consistent live reads over at least two minutes.
- Swift and TypeScript fixture results must match.
- Normal UI separates quota reset time from data refresh time.

---

### Task 1: Define Shared Evidence And Early-Estimate Contracts

**Files:**
- Modify: `Sources/QuotaCapsuleCore/WeeklyRunwayPredictor.swift`
- Modify: `packages/core/src/model.ts`
- Modify: `packages/core/src/index.ts`
- Modify: `fixtures/weekly-runway-cases.json`
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklyFixtureParityTests.swift`
- Modify: `packages/core/test/weekly-runway.test.ts`

**Interfaces:**
- Produces Swift/TypeScript equivalents of `PaceEvidence`, `PaceEvidenceKind`, and `earlyEstimate` runway state.

- [ ] **Step 1: Add failing parity fixtures**

Add cases for:

```json
{
  "id": "first-valid-reading-gives-early-estimate",
  "snapshot": { "usedPercent": 9, "remainingPercent": 91, "resetsAt": "2026-07-20T00:11:00Z" },
  "readings": [{ "fetchedAt": "2026-07-13T05:49:00Z", "usedPercent": 9, "resetsAt": "2026-07-20T00:11:00Z" }],
  "expected": { "qualityState": "stable", "forecastState": "earlyEstimate", "confidence": "low" }
}
```

Also add `first-zero-reading-does-not-claim-zero-pace`, `three-hour-transition-is-actionable`, `burst-then-idle-decays`, and `stale-snapshot-suppresses-estimate`.

- [ ] **Step 2: Run RED in both runtimes**

Run:

```bash
npx vitest run packages/core/test/weekly-runway.test.ts
swift test --filter WeeklyFixtureParityTests
```

Expected: FAIL because `earlyEstimate`, confidence expectations, and evidence fields do not exist.

- [ ] **Step 3: Add the minimal shared model**

Define equivalent types:

```swift
public enum PaceEvidenceKind: String, Codable, Sendable { case cycle, recent, activity, historical }
public struct PaceEvidence: Equatable, Sendable {
    public let kind: PaceEvidenceKind
    public let bandPerDay: PaceBand
    public let reliability: Double
    public let transitionCount: Int
    public let coverageHours: Double
}
```

```ts
export type PaceEvidenceKind = "cycle" | "recent" | "activity" | "historical";
export type PaceEvidence = {
  kind: PaceEvidenceKind;
  bandPerDay: PaceBand;
  reliability: number;
  transitionCount: number;
  coverageHours: number;
};
```

Add `earlyEstimate` / `earlyEstimate` to runway-state enums and `paceEvidence` plus `confidenceReason` to forecast results.

- [ ] **Step 4: Run GREEN for model compilation**

Run TypeScript build and `swift test`; expected: model compiles while behavioral fixture assertions remain the only failures.

- [ ] **Step 5: Commit**

Commit as `Define adaptive weekly forecast evidence`.

### Task 2: Produce Immediate Cycle Evidence

**Files:**
- Create: `Sources/QuotaCapsuleCore/WeeklyPaceEvidence.swift`
- Create: `packages/core/src/weekly-pace-evidence.ts`
- Create: `Tests/QuotaCapsuleCoreTests/WeeklyPaceEvidenceTests.swift`
- Create: `packages/core/test/weekly-pace-evidence.test.ts`

**Interfaces:**
- Produces `cycleEvidence(window:now:) -> PaceEvidence?` and `cycleEvidence(window, now): PaceEvidence | null`.

- [ ] **Step 1: Write failing cycle-evidence tests**

For a 9% reading 5.7 hours into a seven-day cycle, assert a non-empty bounded rate and low reliability. For a zero reading, assert the lower bound is zero and mark it insufficient to claim a zero long-term pace. For an invalid future cycle start, assert `nil/null`.

- [ ] **Step 2: Run RED**

Run targeted Swift and TypeScript tests; expected: missing functions.

- [ ] **Step 3: Implement quantized cycle math**

Use:

```text
used interval = [max(0, used - 0.5), min(100, used + 0.5)]
elapsed days = max((now - (resetAt - 7 days)) / 1 day, epsilon)
pace band = used interval / elapsed days
reliability = clamp(0.10 + 0.45 * sqrt(elapsedFraction), 0.10, 0.55)
```

If reported use is zero, preserve the upper bound but attach zero transitions so classification remains `earlyEstimate` rather than `enough`.

- [ ] **Step 4: Run GREEN and commit**

Run both targeted suites, then commit as `Estimate weekly pace from the first reading`.

### Task 3: Add Recent, Transition, And Activity Evidence

**Files:**
- Modify: `Sources/QuotaCapsuleCore/WeeklyPaceEvidence.swift`
- Modify: `packages/core/src/weekly-pace-evidence.ts`
- Modify: corresponding Swift and TypeScript tests.

**Interfaces:**
- Produces `recentEvidence`, `activityEvidence`, and `upwardTransitions` in both runtimes.

- [ ] **Step 1: Write failing evidence tests**

Cover:

- one upward transition in three hours yields recent evidence without waiting six hours;
- repeated flat samples alone do not inflate confidence;
- a 4% burst followed by 12 idle hours yields a lower activity pace than immediately after the burst;
- a downward correction contributes zero consumption;
- pairwise outlier slopes are clipped by robust quartiles.

- [ ] **Step 2: Run RED**

Expected: missing functions and current six-hour gate failures.

- [ ] **Step 3: Implement robust bounded estimators**

Use observation intervals of ±0.5 points. Recent evidence uses pairwise nonnegative bounded slopes separated by at least 30 minutes and summarizes their 25th/75th percentiles. Activity evidence weights upward transition intervals with a 12-hour exponential half-life and divides by total observed time, so ongoing idle time lowers the pace naturally.

Reliability is bounded `[0,1]` and combines transition count, log-scaled coverage, freshness, and observation spread; duplicate flat samples in one five-minute bucket add no reliability.

- [ ] **Step 4: Run GREEN and commit**

Run both targeted suites and commit as `Model bursty and idle weekly usage`.

### Task 4: Fuse Evidence And Remove The Five-Percent Reserve

**Files:**
- Modify: `Sources/QuotaCapsuleCore/WeeklyRunwayPredictor.swift`
- Modify: `packages/core/src/prediction.ts`
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklyRunwayPredictorTests.swift`
- Modify: `packages/core/test/prediction.test.ts`
- Modify: parity fixtures.

**Interfaces:**
- Produces `fusePaceEvidence(_:) -> PaceBand?`, evidence-based confidence, budget, and classification.

- [ ] **Step 1: Write failing predictor tests**

Assert:

```text
remaining=91, hoursToReset=162.4 -> next24 budget=floor(91/162.4*24)=13
first valid reading -> earlyEstimate, not calibrating
all reliable bands project positive -> enough
fused band crosses zero at reset -> watch
even optimistic band projects negative -> mayRunOut
stale -> unavailable with cached percentages only
```

- [ ] **Step 2: Run RED**

Expected: failures from the six-hour gate, five-point reserve, and old classification.

- [ ] **Step 3: Implement robust fusion**

Remove `minimumCoverage` and `reservePercent`. Fuse lower and upper bounds separately using reliability-weighted medians, widen the result when estimators disagree, and cap nonsensical rates. Compute:

```text
sustainablePerDay = remaining / daysRemaining
projectedRemaining = remaining - fusedPace * daysRemaining
next24Budget = floor(remaining / hoursRemaining * min(24, hoursRemaining))
```

Confidence is low with cycle-only evidence, medium with at least one real transition plus estimator agreement, and high only with three or more spread transitions, meaningful coverage, freshness, and agreement.

- [ ] **Step 4: Run GREEN, parity, and commit**

Run all predictor/fixture tests in both runtimes; commit as `Fuse adaptive weekly pace evidence`.

### Task 5: Make Early Value And Time Semantics Explicit In Copy

**Files:**
- Modify: `Sources/QuotaCapsuleCore/CapsuleDisplayModel.swift`
- Modify: `Sources/QuotaCapsuleCore/QuotaLocale.swift`
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklyDisplayModelTests.swift`
- Modify: `apps/desktop/src/capsule-view.ts`
- Modify: `apps/desktop/src/capsule-view.test.ts`

**Interfaces:**
- Produces localized preliminary copy, reset timestamp/countdown labels, and data-read freshness labels.

- [ ] **Step 1: Write failing display tests**

Require Chinese output equivalent to:

```text
初步判断：按本周平均速度可能偏快
周额度将在 7月20日 08:11 重置（6天18小时后）
数据更新于 13:49:44，下次自动读取约 47 秒后
```

Assert `刷新时间` is not used as the quota-reset title and `正在校准，积累 6 小时` never appears.

- [ ] **Step 2: Run RED**

Run display model and desktop view tests; expected: old ambiguous copy fails.

- [ ] **Step 3: Implement minimal localized copy**

Add distinct localization APIs:

```swift
func quotaResetDescription(resetsAt: Date, now: Date) -> String
func dataRefreshDescription(lastSuccess: Date?, nextAttempt: Date?, now: Date) -> String
func confidenceReason(_ forecast: WeeklyRunwayForecast) -> String
```

Keep source/endpoint details inside diagnostics.

- [ ] **Step 4: Run GREEN and commit**

Run targeted and full copy tests; commit as `Clarify weekly reset and data freshness`.

### Task 6: Update The Native Capsule Hierarchy

**Files:**
- Modify: `Sources/QuotaCapsuleMac/QuotaStore.swift`
- Modify: `Sources/QuotaCapsuleMac/CapsuleViews.swift`
- Modify: `Sources/QuotaCapsuleMac/CapsulePanelController.swift` if sizing changes.
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklyDisplayModelTests.swift`

**Interfaces:**
- Consumes: forecast/display contracts from Tasks 1-5.
- Produces: collapsed and expanded Weekly Only surfaces with preliminary value and explicit timing.

- [ ] **Step 1: Add failing view-model assertions**

Assert the expanded model orders: outcome, time/usage, next-24 budget, forecast/confidence, pace comparison, trend, reset, data freshness, actions/diagnostics. Assert collapsed copy contains outcome, weekly used, reason, progress, and optional reset countdown.

- [ ] **Step 2: Run RED**

Expected: current model lacks separate next-attempt countdown and early-estimate presentation.

- [ ] **Step 3: Implement the hierarchy**

Expose `lastSuccessfulReadAt`, `nextAutomaticReadAt`, and reset countdown from `QuotaStore`. Use a timer for countdown rendering without triggering network reads. Render confidence as text plus uncertainty band; never rely on color alone.

- [ ] **Step 4: Run automated and deterministic mock checks**

Run Swift tests/spec and render every state: early estimate, enough, watch, may run out, exhausted, stale, unavailable, and reset pending.

- [ ] **Step 5: Commit**

Commit as `Show adaptive weekly guidance immediately`.

### Task 7: Document The Forecast Method And Product Contract

**Files:**
- Create: `docs/product/forecast-methodology.md`
- Modify: `docs/product/brief.md`
- Modify: `docs/product/mvp-scope.md`
- Modify: `docs/product/acceptance-criteria.md`
- Modify: `docs/product/feature-roadmap.md`
- Modify: `docs/product/visual-design-direction.md`
- Modify: `docs/product/bug-triage-and-release-blockers.md`
- Modify: `README.md`, `README.zh-CN.md`, `README.en.md`, `CHANGELOG.md`.

- [ ] **Step 1: Add a failing repository-policy assertion**

Require the maintained docs to contain the first-reading behavior, quantization interval, evidence types, confidence rules, next-24 formula, stale behavior, and separate reset/data times; reject the fixed six-hour rule and five-percent reserve wording.

- [ ] **Step 2: Run RED**

Expected: old docs fail.

- [ ] **Step 3: Write public methodology and update every current product document**

Include equations, assumptions, plain-language examples, known limits, and an iteration rule: algorithm changes require fixture changes and changelog entries in the same PR.

- [ ] **Step 4: Run GREEN and commit**

Run repository audit and Markdown-link checks; commit as `Document adaptive weekly forecasting`.

### Task 8: Full Verification, Pull Request, Release, And Real-Use Acceptance

**Files:**
- Modify: version metadata and `CHANGELOG.md` for `v0.3.0-beta.1`.
- Produce: release artifact, checksum, screenshots, and release notes.

- [ ] **Step 1: Run the clean automated suite**

```bash
npm test
npm run lint
npm run build
npm run audit:repository
swift test
swift run QuotaCapsuleCoreSpec
swift build --product QuotaCapsuleMac
npm run mac:package
git diff --check
```

Expected: all pass with no warnings that invalidate release confidence.

- [ ] **Step 2: Review deterministic UI states**

Capture and inspect collapsed/expanded states on light, dark, and busy backgrounds. Verify contrast, clipping, hierarchy, reset countdown, data-read countdown, and no duplicate panel.

- [ ] **Step 3: Push, open PR, review, and merge**

Confirm every commit is authored by `Bono12138`, CI passes, repository audit passes, and review findings are resolved with new regression tests before merge.

- [ ] **Step 4: Build release from exact public main**

Set version `0.3.0`, package the Beta, verify signature, archive checksum, create `v0.3.0-beta.1`, and publish release notes that explain the preliminary forecast and uncertainty.

- [ ] **Step 5: Install and verify one real app**

Install `/Applications/Quota Capsule Beta.app`, verify its executable path, version, commit fingerprint, live source success, history continuity, Spotlight count, and exactly one running `QuotaCapsuleBeta` process.

- [ ] **Step 6: Perform real-use observation**

Use Codex, observe at least one actual percentage transition or a meaningful idle interval, and confirm the forecast updates without a six-hour wait. Compare live UI values with a read-only database query before claiming completion.

- [ ] **Step 7: Record the release retrospective**

Document what was predicted, what was observed, any remaining uncertainty, and the exact verification evidence. Do not claim the release is fixed from build/test success alone.
