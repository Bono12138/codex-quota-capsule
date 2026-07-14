# Forecast Stability and Menu Lifetime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make weekly pace evidence polling-invariant, render honest positive/negative/cross-zero projections, replace normalized daily copy with the actual observed period, and eliminate status-menu flicker.

**Architecture:** Keep all forecast arithmetic in `QuotaCapsuleCore` and its TypeScript parity package. Add one provider-neutral observed-usage summary to the forecast, use median/MAD fusion, and keep raw negative projections through the display boundary. Move menu update decisions into a pure equatable gate so one-second clock ticks cannot replace an `NSMenu` while AppKit is tracking it.

**Tech Stack:** Swift 6, Swift Testing, Foundation, AppKit, Combine, TypeScript 5, Vitest, JSON parity fixtures

## Global Constraints

- Target release is `v0.3.1-beta.1`.
- The public `Bono12138/codex-quota-capsule` repository is the only source of truth.
- Keep one installed application named `Quota Capsule Beta.app`; do not create a persistent Dev app.
- The normal UI remains Weekly Only and contains no five-hour-window copy.
- Forecast production code is written only after the corresponding regression test fails.
- Raw projections remain mathematical values; the display layer may explain them but may not silently clamp a negative endpoint to zero.
- Swift and TypeScript must agree on shared fixture classifications and numeric tolerances.
- Commits use `Bono12138 <Bono12138@users.noreply.github.com>` with no co-author trailers.

---

## File structure

- `Sources/QuotaCapsuleCore/WeeklyPaceEvidence.swift`: polling-invariant activity measurement and robust fusion.
- `Sources/QuotaCapsuleCore/WeeklyRunwayPredictor.swift`: observed-period summary, confidence, and raw projection semantics.
- `Sources/QuotaCapsuleCore/CapsuleDisplayModel.swift`: positive, negative, and cross-zero user copy.
- `Sources/QuotaCapsuleCore/QuotaLocale.swift`: localized observed-period and diagnostic pace copy.
- `packages/core/src/model.ts`: TypeScript parity types.
- `packages/core/src/weekly-pace-evidence.ts`: TypeScript activity and fusion parity.
- `packages/core/src/prediction.ts`: TypeScript forecast parity.
- `fixtures/weekly-pace-equivalence.json`: polling-layout invariance fixtures without personal timestamps.
- `Tests/QuotaCapsuleCoreTests/WeeklyPaceEvidenceTests.swift`: Swift estimator regressions.
- `Tests/QuotaCapsuleCoreTests/WeeklyRunwayPredictorTests.swift`: confidence and projection regressions.
- `Tests/QuotaCapsuleCoreTests/WeeklyDisplayModelTests.swift`: copy and formatting regressions.
- `Tests/QuotaCapsuleCoreTests/WeeklyFixtureParityTests.swift`: Swift shared-fixture runner.
- `packages/core/test/weekly-pace-evidence.test.ts`: TypeScript estimator regressions.
- `packages/core/test/weekly-runway.test.ts`: TypeScript shared-fixture runner.
- `Sources/QuotaCapsuleMac/StatusBarPresentation.swift`: menu presentation value and tracking gate.
- `Sources/QuotaCapsuleMac/QuotaStore.swift`: publishes status presentation only when menu-relevant data changes.
- `Sources/QuotaCapsuleMac/StatusBarController.swift`: applies or defers menu updates through the gate.
- `Tests/QuotaCapsuleMacTests/StatusBarPresentationTests.swift`: pure menu-update regressions.
- `Package.swift`: adds the macOS test target.

---

### Task 1: Make activity evidence invariant to flat and duplicate polling

**Files:**
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklyPaceEvidenceTests.swift`
- Modify: `packages/core/test/weekly-pace-evidence.test.ts`
- Modify: `Sources/QuotaCapsuleCore/WeeklyPaceEvidence.swift`
- Modify: `packages/core/src/weekly-pace-evidence.ts`

**Interfaces:**
- Consumes: ordered `WeeklyObservation` values from the current quality-approved segment.
- Produces: `activitySegments(observations:now:) -> ActivitySegmentSummary?` and `activitySegments(observations, now) -> ActivitySegmentSummary | null` whose `observedIncreaseBand` depends on monotonic segment endpoints, not poll count.

- [ ] **Step 1: Add failing Swift invariance tests**

Add these cases inside `WeeklyPaceEvidenceTests`:

```swift
@Test("flat polls do not add endpoint uncertainty")
func flatPollsDoNotWidenActivityBand() throws {
    let sparse = [
        observation(at: now.addingTimeInterval(-8 * 3_600), used: 1),
        observation(at: now, used: 18)
    ]
    let polled = [1.0, 1, 4, 4, 7, 7, 10, 10, 13, 13, 16, 16, 18].enumerated().map { index, used in
        observation(
            at: now.addingTimeInterval(Double(index - 12) * 40 * 60),
            used: used
        )
    }

    let sparseSummary = try #require(WeeklyPaceEvidence.activitySegments(observations: sparse, now: now))
    let polledSummary = try #require(WeeklyPaceEvidence.activitySegments(observations: polled, now: now))

    #expect(sparseSummary.observedIncreaseBand == PaceBand(lower: 16, upper: 18))
    #expect(polledSummary.observedIncreaseBand == sparseSummary.observedIncreaseBand)
}

@Test("duplicates do not change activity uncertainty")
func duplicatePollsDoNotChangeActivityBand() throws {
    let base = observations(values: [5, 6, 7], spacingHours: 1)
    let duplicated = [base[0], base[1], base[1], base[2]]
    let baseSummary = try #require(WeeklyPaceEvidence.activitySegments(observations: base, now: now))
    let duplicateSummary = try #require(WeeklyPaceEvidence.activitySegments(observations: duplicated, now: now))

    #expect(baseSummary.observedIncreaseBand == PaceBand(lower: 1, upper: 3))
    #expect(duplicateSummary.observedIncreaseBand == baseSummary.observedIncreaseBand)
}

@Test("a correction starts a new measurement segment")
func correctionStartsNewMeasurementSegment() throws {
    let samples = observations(values: [5, 9, 8, 10], spacingHours: 1)
    let summary = try #require(WeeklyPaceEvidence.activitySegments(observations: samples, now: now))

    #expect(summary.observedIncreaseBand == PaceBand(lower: 4, upper: 8))
}
```

- [ ] **Step 2: Add equivalent failing TypeScript tests**

Add the same three histories to `packages/core/test/weekly-pace-evidence.test.ts` and assert:

```ts
expect(activitySegments(sparse, now)?.observedIncreaseBand).toEqual({ lower: 16, upper: 18 });
expect(activitySegments(polled, now)?.observedIncreaseBand).toEqual({ lower: 16, upper: 18 });
expect(activitySegments(duplicated, now)?.observedIncreaseBand).toEqual({ lower: 1, upper: 3 });
expect(activitySegments(correction, now)?.observedIncreaseBand).toEqual({ lower: 4, upper: 8 });
```

- [ ] **Step 3: Run both focused suites and verify the regression**

Run:

```bash
swift test --filter WeeklyPaceEvidenceTests
npx vitest run packages/core/test/weekly-pace-evidence.test.ts
```

Expected: the flat/duplicate tests fail because the current run-flushing algorithm pays endpoint uncertainty repeatedly.

- [ ] **Step 4: Replace run flushing with monotonic-segment measurement in Swift**

In `activitySegments`, keep gap classification but replace `increaseRunStart` and `increaseRunEnd` with:

```swift
var measurementStart = first
var measurementEnd = first

func flushMeasurement() {
    guard measurementEnd.usedPercent > measurementStart.usedPercent else { return }
    let startInterval = quantizedInterval(measurementStart.usedPercent)
    let endInterval = quantizedInterval(measurementEnd.usedPercent)
    observedIncreaseLower += max(0, endInterval.lower - startInterval.upper)
    observedIncreaseUpper += max(0, endInterval.upper - startInterval.lower)
}
```

For each ordered pair, keep the segment open for equal or increasing values and split only on a real downward correction:

```swift
if later.usedPercent < earlier.usedPercent {
    flushMeasurement()
    measurementStart = later
    measurementEnd = later
} else {
    measurementEnd = later
}
```

Call `flushMeasurement()` once after the loop. Duplicate timestamps continue to be ignored by the existing `gap > 0` guard and do not affect endpoints.

- [ ] **Step 5: Implement the identical rule in TypeScript**

Use the same `measurementStart`, `measurementEnd`, downward-split, and endpoint interval equations in `packages/core/src/weekly-pace-evidence.ts`.

- [ ] **Step 6: Run the focused suites and commit**

Run the two Step 3 commands. Expected: PASS.

Commit:

```bash
git add Sources/QuotaCapsuleCore/WeeklyPaceEvidence.swift Tests/QuotaCapsuleCoreTests/WeeklyPaceEvidenceTests.swift packages/core/src/weekly-pace-evidence.ts packages/core/test/weekly-pace-evidence.test.ts
git commit -m "Fix polling-invariant activity evidence"
```

---

### Task 2: Replace quantile fusion with median/MAD consensus

**Files:**
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklyPaceEvidenceTests.swift`
- Modify: `packages/core/test/weekly-pace-evidence.test.ts`
- Modify: `Sources/QuotaCapsuleCore/WeeklyPaceEvidence.swift`
- Modify: `packages/core/src/weekly-pace-evidence.ts`
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklyRunwayPredictorTests.swift`
- Modify: `Sources/QuotaCapsuleCore/WeeklyRunwayPredictor.swift`
- Modify: `packages/core/src/prediction.ts`

**Interfaces:**
- Consumes: valid `PaceEvidence` values.
- Produces: `fuse`/`fusePaceEvidence` using a one-source band, two-source hull, or three-plus-source median/MAD band.
- Produces: pure `confidence`/`forecastConfidenceForEvidence` helpers so coverage and decision-agreement rules are directly testable.

- [ ] **Step 1: Add failing fusion tests**

Create a small evidence helper and these assertions in Swift:

```swift
func evidence(_ kind: PaceEvidenceKind, _ lower: Double, _ upper: Double) -> PaceEvidence {
    PaceEvidence(
        kind: kind,
        bandPerDay: PaceBand(lower: lower, upper: upper),
        reliability: 0.6,
        transitionCount: 2,
        coverageHours: 8
    )
}

@Test("three-source fusion resists one wide outlier")
func fusionUsesMedianMAD() throws {
    let fused = try #require(WeeklyPaceEvidence.fuse([
        evidence(.cycle, 46, 50),
        evidence(.recent, 48, 54),
        evidence(.activity, 5, 92)
    ]))

    #expect(abs(fused.lower - 45.5) < 0.000_001)
    #expect(abs(fused.upper - 51.5) < 0.000_001)
}

@Test("two-source fusion returns the honest hull")
func twoSourceFusionUsesHull() throws {
    let fused = try #require(WeeklyPaceEvidence.fuse([
        evidence(.cycle, 8, 10),
        evidence(.recent, 14, 18)
    ]))
    #expect(fused == PaceBand(lower: 8, upper: 18))
}
```

Add equivalent tests to TypeScript with `fusePaceEvidence` and assert the exact
`{ lower: 45.5, upper: 51.5 }` result within `0.000001`.

- [ ] **Step 2: Verify both old implementations fail**

Run:

```bash
swift test --filter WeeklyPaceEvidenceTests
npx vitest run packages/core/test/weekly-pace-evidence.test.ts
```

Expected: the three-source test returns an outlier-controlled endpoint under weighted quartiles.

- [ ] **Step 3: Implement the exact median/MAD contract in Swift**

Replace `fuse` with:

```swift
public static func fuse(_ evidence: [PaceEvidence]) -> PaceBand? {
    let valid = evidence.filter {
        $0.reliability.isFinite && $0.reliability > 0
            && $0.coverageHours.isFinite && $0.coverageHours >= 0
            && $0.bandPerDay.lower.isFinite && $0.bandPerDay.upper.isFinite
            && $0.bandPerDay.lower >= 0
            && $0.bandPerDay.upper >= $0.bandPerDay.lower
    }
    guard !valid.isEmpty else { return nil }
    if valid.count == 1 { return valid[0].bandPerDay }
    if valid.count == 2 {
        return PaceBand(
            lower: min(valid[0].bandPerDay.lower, valid[1].bandPerDay.lower),
            upper: max(valid[0].bandPerDay.upper, valid[1].bandPerDay.upper)
        )
    }

    let midpoints = valid.map { ($0.bandPerDay.lower + $0.bandPerDay.upper) / 2 }
    let center = median(midpoints)
    let within = median(valid.map { ($0.bandPerDay.upper - $0.bandPerDay.lower) / 2 })
    let disagreement = 1.4826 * median(midpoints.map { abs($0 - center) })
    let halfWidth = max(within, disagreement)
    return PaceBand(lower: max(0, center - halfWidth), upper: center + halfWidth)
}
```

Delete the unused `weightedQuantile` helper.

- [ ] **Step 4: Implement byte-for-byte-equivalent equations in TypeScript**

Filter the same invalid evidence, use the same one/two/many branches and `1.4826` MAD scale, and delete the weighted-quantile helper.

- [ ] **Step 5: Add decision-agreement confidence tests**

Add a pure confidence helper and direct tests in `WeeklyPaceEvidenceTests.swift`:

```swift
@Test("decision disagreement forces low confidence")
func decisionDisagreementIsLowConfidence() {
    let paths = [
        evidence(.cycle, 7, 9),
        evidence(.recent, 11, 13),
        evidence(.activity, 16, 18)
    ]
    #expect(WeeklyPaceEvidence.confidence(
        evidence: paths,
        coverageHours: 24,
        transitionCount: 3,
        sustainable: 12
    ) == .low)
}

@Test("agreement needs coverage before confidence rises")
func agreementUsesCoverageThresholds() {
    let paths = [
        evidence(.cycle, 8, 10),
        evidence(.recent, 9, 11),
        evidence(.activity, 10, 12)
    ]
    #expect(WeeklyPaceEvidence.confidence(
        evidence: paths,
        coverageHours: 2.99,
        transitionCount: 1,
        sustainable: 14
    ) == .low)
    #expect(WeeklyPaceEvidence.confidence(
        evidence: paths,
        coverageHours: 3,
        transitionCount: 1,
        sustainable: 14
    ) == .medium)
    #expect(WeeklyPaceEvidence.confidence(
        evidence: paths,
        coverageHours: 24,
        transitionCount: 3,
        sustainable: 14
    ) == .high)
}
```

Add exact TypeScript equivalents for `forecastConfidenceForEvidence`.

The confidence implementation must use this decision bucket:

```swift
private static func paceDecision(_ evidence: PaceEvidence, sustainable: Double) -> Int {
    let midpoint = (evidence.bandPerDay.lower + evidence.bandPerDay.upper) / 2
    if midpoint < sustainable * 0.90 { return -1 }
    if midpoint > sustainable * 1.10 { return 1 }
    return 0
}
```

Return low when valid evidence contains more than one decision bucket. Return high only with at least 24 hours of coverage, at least three upward transitions, at least three valid sources, and relative midpoint spread at most `0.5`. Return medium only when there are at least two valid sources in one decision bucket, active-segment coverage is at least three hours, there is at least one upward transition, and the maximum source reliability is at least `0.25`; otherwise return low.

Change `WeeklyRunwayPredictor.forecastConfidence` and TypeScript `predictWeeklyRunway` to call this helper with active-segment coverage in hours instead of maintaining a second confidence implementation.

- [ ] **Step 6: Mirror confidence behavior in TypeScript and run tests**

Run:

```bash
swift test --filter WeeklyPaceEvidenceTests
swift test --filter WeeklyRunwayPredictorTests
npx vitest run packages/core/test/weekly-pace-evidence.test.ts packages/core/test/weekly-runway.test.ts
```

Expected: PASS.

Commit:

```bash
git add Sources/QuotaCapsuleCore/WeeklyPaceEvidence.swift Sources/QuotaCapsuleCore/WeeklyRunwayPredictor.swift Tests/QuotaCapsuleCoreTests/WeeklyPaceEvidenceTests.swift Tests/QuotaCapsuleCoreTests/WeeklyRunwayPredictorTests.swift packages/core/src/weekly-pace-evidence.ts packages/core/src/prediction.ts packages/core/test/weekly-pace-evidence.test.ts packages/core/test/weekly-runway.test.ts
git commit -m "Use robust weekly pace consensus"
```

---

### Task 3: Show the actual observed period and honest projection scenarios

**Files:**
- Modify: `Sources/QuotaCapsuleCore/WeeklyRunwayPredictor.swift`
- Modify: `Sources/QuotaCapsuleCore/CapsuleDisplayModel.swift`
- Modify: `Sources/QuotaCapsuleCore/QuotaLocale.swift`
- Modify: `Sources/QuotaCapsuleMac/QuotaStore.swift`
- Modify: `Sources/QuotaCapsuleMac/CapsuleViews.swift`
- Modify: `packages/core/src/model.ts`
- Modify: `packages/core/src/prediction.ts`
- Modify: `packages/core/src/copy.ts`
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklyDisplayModelTests.swift`
- Modify: `packages/core/test/weekly-runway.test.ts`

**Interfaces:**
- Produces: `ObservedUsageSummary(coverageSeconds:increaseBand:)` and TypeScript parity type.
- Produces: display copy that distinguishes positive, negative, crossing-zero, and unavailable projections without clamping.

- [ ] **Step 1: Add failing display tests**

Extend the forecast helper with `observedUsage` and add:

```swift
@Test("cross-zero projection is described as two scenarios")
func crossZeroProjectionIsExplicit() {
    let model = CapsuleDisplayModel.make(
        forecast: forecast(state: .watch, projected: PercentageBand(lower: -22, upper: 44)),
        locale: .zhHans
    )
    #expect(model.defaultText == "按较快节奏可能提前用完；较慢情景重置时最多剩 44%")
    #expect(!model.defaultText.contains("0–44"))
}

@Test("positive projection uses whole-percent precision")
func positiveProjectionUsesWholePercent() {
    let model = CapsuleDisplayModel.make(
        forecast: forecast(projected: PercentageBand(lower: 12.2, upper: 18.8)),
        locale: .zhHans
    )
    #expect(model.defaultText == "照最近速度，重置时预计剩 12%–19%")
}

@Test("observed usage names the real coverage period")
func observedUsageUsesRealCoverage() {
    let copy = QuotaCopy(locale: .zhHans)
    let text = copy.observedUsage(
        ObservedUsageSummary(
            coverageSeconds: 8 * 3_600 + 15 * 60,
            increaseBand: PercentageBand(lower: 16, upper: 18)
        )
    )
    #expect(text == "近 8 小时 15 分钟已用约 16%–18%")
    #expect(!text.contains("/天"))
}
```

- [ ] **Step 2: Run the display test and verify failure**

Run `swift test --filter WeeklyDisplayModelTests`.

Expected: the cross-zero path currently clamps to `0–44%`, uses decimals, and has no observed-period API.

- [ ] **Step 3: Add observed-usage types and predictor output**

Add this Swift type beside `PercentageBand` and its TypeScript equivalent:

```swift
public struct ObservedUsageSummary: Equatable, Sendable {
    public let coverageSeconds: TimeInterval
    public let increaseBand: PercentageBand

    public init(coverageSeconds: TimeInterval, increaseBand: PercentageBand) {
        self.coverageSeconds = coverageSeconds
        self.increaseBand = increaseBand
    }
}
```

Add `observedUsage: ObservedUsageSummary?` to `WeeklyRunwayForecast` with a default of `nil`. Build it from the first and last observations of the active clean segment using one quantized endpoint interval:

```swift
let start = WeeklyPaceEvidence.quantizedInterval(first.usedPercent)
let end = WeeklyPaceEvidence.quantizedInterval(last.usedPercent)
let observedUsage = ObservedUsageSummary(
    coverageSeconds: last.fetchedAt.timeIntervalSince(first.fetchedAt),
    increaseBand: PercentageBand(
        lower: max(0, end.lower - start.upper),
        upper: max(0, end.upper - start.lower)
    )
)
```

Return `nil` when coverage is non-positive or no increase is observed.

- [ ] **Step 4: Replace normalized main copy and preserve diagnostics**

Add localized `observedUsage(_:)` formatting in `QuotaLocale.swift`. Use hours and minutes, round projection endpoints to whole percentages, and leave `%/天` only in an explicitly labelled diagnostic method.

Replace the main `paceComparisonText` label in `CapsuleViews.swift` with `store.observedUsageText`. Move normalized pace and sustainable pace into the expanded diagnostics disclosure.

- [ ] **Step 5: Remove projection clamping from decision copy**

Replace the projection formatter with this branch structure:

```swift
guard let band, band.lower.isFinite, band.upper.isFinite else { return accumulatingCopy }
if band.upper < 0 { return mayRunOutCopy }
if band.lower < 0 {
    return crossZeroCopy(maxRemaining: Int(band.upper.rounded()))
}
return positiveRangeCopy(
    lower: Int(band.lower.rounded()),
    upper: Int(band.upper.rounded())
)
```

Keep numeric clamping only for true current percentages and observed-use percentages, never for reset projections.

- [ ] **Step 6: Mirror model, predictor, and copy in TypeScript**

Add:

```ts
export type ObservedUsageSummary = {
  coverageSeconds: number;
  increaseBand: PercentageBand;
};
```

Use the same endpoint calculation and projection branches in `packages/core`.

- [ ] **Step 7: Run focused tests and commit**

Run:

```bash
swift test --filter WeeklyDisplayModelTests
swift test --filter WeeklyRunwayPredictorTests
npx vitest run packages/core/test/weekly-runway.test.ts packages/core/test/prediction.test.ts
```

Expected: PASS with no normal user-facing `%/day` line and no silent `0–Y%` projection.

Commit:

```bash
git add Sources/QuotaCapsuleCore/WeeklyRunwayPredictor.swift Sources/QuotaCapsuleCore/CapsuleDisplayModel.swift Sources/QuotaCapsuleCore/QuotaLocale.swift Sources/QuotaCapsuleMac/QuotaStore.swift Sources/QuotaCapsuleMac/CapsuleViews.swift Tests/QuotaCapsuleCoreTests/WeeklyDisplayModelTests.swift Tests/QuotaCapsuleCoreTests/WeeklyRunwayPredictorTests.swift packages/core/src/model.ts packages/core/src/prediction.ts packages/core/src/copy.ts packages/core/test/weekly-runway.test.ts packages/core/test/prediction.test.ts
git commit -m "Explain observed weekly usage honestly"
```

---

### Task 4: Add shared polling-equivalence fixtures

**Files:**
- Create: `fixtures/weekly-pace-equivalence.json`
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklyFixtureParityTests.swift`
- Modify: `packages/core/test/weekly-runway.test.ts`

**Interfaces:**
- Produces: one public fixture format containing `id`, `now`, `sparse`, `polled`, and `expectedIncreaseBand`.

- [ ] **Step 1: Create the non-personal regression fixture**

Use this complete fixture:

```json
{
  "version": 1,
  "cases": [
    {
      "id": "flat-polls-preserve-endpoint-uncertainty",
      "now": "2030-01-01T08:00:00Z",
      "sparse": [
        { "hoursBeforeNow": 8, "usedPercent": 1 },
        { "hoursBeforeNow": 0, "usedPercent": 18 }
      ],
      "polled": [
        { "hoursBeforeNow": 8, "usedPercent": 1 },
        { "hoursBeforeNow": 7.3333333333, "usedPercent": 1 },
        { "hoursBeforeNow": 6.6666666667, "usedPercent": 4 },
        { "hoursBeforeNow": 6, "usedPercent": 4 },
        { "hoursBeforeNow": 5.3333333333, "usedPercent": 7 },
        { "hoursBeforeNow": 4.6666666667, "usedPercent": 7 },
        { "hoursBeforeNow": 4, "usedPercent": 10 },
        { "hoursBeforeNow": 3.3333333333, "usedPercent": 10 },
        { "hoursBeforeNow": 2.6666666667, "usedPercent": 13 },
        { "hoursBeforeNow": 2, "usedPercent": 13 },
        { "hoursBeforeNow": 1.3333333333, "usedPercent": 16 },
        { "hoursBeforeNow": 0.6666666667, "usedPercent": 16 },
        { "hoursBeforeNow": 0, "usedPercent": 18 }
      ],
      "expectedIncreaseBand": { "lower": 16, "upper": 18 }
    }
  ]
}
```

- [ ] **Step 2: Add Swift and TypeScript fixture runners**

Both runners must decode every case, create cycle/segment-zero observations, run `activitySegments`, and assert both variants equal `expectedIncreaseBand` within `0.000001`.

- [ ] **Step 3: Run parity tests and commit**

Run:

```bash
swift test --filter WeeklyFixtureParityTests
npx vitest run packages/core/test/weekly-runway.test.ts
```

Expected: PASS.

Commit:

```bash
git add fixtures/weekly-pace-equivalence.json Tests/QuotaCapsuleCoreTests/WeeklyFixtureParityTests.swift packages/core/test/weekly-runway.test.ts
git commit -m "Add polling equivalence fixtures"
```

---

### Task 5: Prevent menu rebuilds during clock ticks and menu tracking

**Files:**
- Modify: `Package.swift`
- Create: `Sources/QuotaCapsuleMac/StatusBarPresentation.swift`
- Create: `Tests/QuotaCapsuleMacTests/StatusBarPresentationTests.swift`
- Modify: `Sources/QuotaCapsuleMac/QuotaStore.swift`
- Modify: `Sources/QuotaCapsuleMac/StatusBarController.swift`

**Interfaces:**
- Produces: `StatusBarPresentation: Equatable` containing every string used to render the status button/menu.
- Produces: `StatusBarUpdateGate<Value: Equatable>` with `receive`, `beginTracking`, and `endTracking`.

- [ ] **Step 1: Add the macOS test target and failing gate tests**

Add to `Package.swift`:

```swift
.testTarget(
    name: "QuotaCapsuleMacTests",
    dependencies: ["QuotaCapsuleMac", "QuotaCapsuleCore"]
)
```

Create `StatusBarPresentationTests.swift`:

```swift
@testable import QuotaCapsuleMac
import Testing

@Suite("Status bar update gate")
struct StatusBarPresentationTests {
    @Test("identical clock-tick presentations do not rebuild")
    func identicalPresentationsAreDeduplicated() {
        var gate = StatusBarUpdateGate<String>()
        #expect(gate.receive("stable") == "stable")
        for _ in 0..<10 { #expect(gate.receive("stable") == nil) }
    }

    @Test("tracking coalesces changes and applies the latest once")
    func trackingDefersLatestPresentation() {
        var gate = StatusBarUpdateGate<String>()
        #expect(gate.receive("initial") == "initial")
        gate.beginTracking()
        #expect(gate.receive("first") == nil)
        #expect(gate.receive("latest") == nil)
        #expect(gate.endTracking() == "latest")
        #expect(gate.endTracking() == nil)
    }

    @Test("tracking reversion cancels a stale pending rebuild")
    func trackingReversionCancelsPendingValue() {
        var gate = StatusBarUpdateGate<String>()
        #expect(gate.receive("initial") == "initial")
        gate.beginTracking()
        #expect(gate.receive("temporary") == nil)
        #expect(gate.receive("initial") == nil)
        #expect(gate.endTracking() == nil)
    }
}
```

- [ ] **Step 2: Run the test and verify missing types**

Run `swift test --filter StatusBarPresentationTests`.

Expected: FAIL because `StatusBarUpdateGate` does not exist.

- [ ] **Step 3: Implement the pure gate**

Create:

```swift
struct StatusBarUpdateGate<Value: Equatable> {
    private(set) var applied: Value?
    private var pending: Value?
    private var isTracking = false

    mutating func receive(_ value: Value) -> Value? {
        if isTracking {
            if value == applied {
                pending = nil
                return nil
            }
            if value == pending { return nil }
            pending = value
            return nil
        }
        guard value != applied else { return nil }
        applied = value
        return value
    }

    mutating func beginTracking() {
        isTracking = true
    }

    mutating func endTracking() -> Value? {
        guard isTracking else { return nil }
        isTracking = false
        guard let pending else { return nil }
        self.pending = nil
        applied = pending
        return pending
    }
}
```

Define `StatusBarPresentation` with button title, tooltip, header, refresh/toggle/guide/language/contact/about/feedback/quit titles, locale selection labels, and contact lines. Its factory consumes current store data but not `currentTime`.

- [ ] **Step 4: Publish presentation changes separately from the one-second clock**

Add `@Published private(set) var statusBarPresentation` to `QuotaStore`. Initialize it from the first display model and refresh it only after:

- accepted or stale quota-state changes;
- locale changes;
- onboarding/settings changes that alter menu strings.

Do not refresh it inside the one-second `clockTask`.

- [ ] **Step 5: Apply the gate from `StatusBarController`**

Make the controller an `NSObject, NSMenuDelegate`, subscribe to `store.$statusBarPresentation.removeDuplicates()`, and remove the `store.objectWillChange` subscription.

Use:

```swift
private func receive(_ presentation: StatusBarPresentation) {
    guard let next = updateGate.receive(presentation) else { return }
    apply(next)
}

func menuWillOpen(_ menu: NSMenu) {
    updateGate.beginTracking()
}

func menuDidClose(_ menu: NSMenu) {
    guard let next = updateGate.endTracking() else { return }
    apply(next)
}
```

Assign `menu.delegate = self` for the status menu. `apply` updates the button and builds the menu from the passed immutable presentation, never by rereading a mutating store halfway through rendering.

- [ ] **Step 6: Run tests and compile the app**

Run:

```bash
swift test --filter StatusBarPresentationTests
swift build --product QuotaCapsuleMac
```

Expected: PASS and successful build.

Commit:

```bash
git add Package.swift Sources/QuotaCapsuleMac/StatusBarPresentation.swift Sources/QuotaCapsuleMac/QuotaStore.swift Sources/QuotaCapsuleMac/StatusBarController.swift Tests/QuotaCapsuleMacTests/StatusBarPresentationTests.swift
git commit -m "Stabilize status menu lifetime"
```

---

### Task 6: Update forecast documentation and run the full gate

**Files:**
- Modify: `docs/product/forecast-methodology.md`
- Modify: `docs/product/acceptance-criteria.md`
- Modify: `docs/product/bug-triage-and-release-blockers.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Produces: public documentation matching the implemented estimator and UI behavior.

- [ ] **Step 1: Replace obsolete methodology**

Document these exact rules:

- one endpoint quantization interval per clean monotonic segment;
- flat/duplicate polling does not widen uncertainty;
- three-plus-source median/MAD, two-source hull, one-source low confidence;
- raw negative reset projections;
- actual observed-period copy in normal UI;
- normalized daily pace only in diagnostics.

Delete the old statement that every separated upward run contributes its own endpoint uncertainty.

- [ ] **Step 2: Add acceptance criteria**

Add explicit checks for:

- equivalent sparse and flat-polled histories;
- fully positive, fully negative, and crossing-zero projections;
- no `0–Y%` produced by clamping;
- no main-surface `%/天` copy;
- Language submenu stays open for ten seconds without closing/reopening.

- [ ] **Step 3: Run every automated gate**

Run:

```bash
swift test
swift run QuotaCapsuleCoreSpec
swift build --product QuotaCapsuleMac
npm test
npm run lint
npm run build
npm run audit:weekly-only
npm run audit:repository
git diff --check
```

Expected: every command exits zero.

- [ ] **Step 4: Review the diff for false completion risks**

Run:

```bash
git diff --stat
git diff --check
rg -n "0–[0-9]|%/天|5 小时|5 小時|5-hour" Sources packages docs/product
```

Expected: any `%/天` match is restricted to diagnostic copy/methodology; no normal UI or five-hour copy remains.

- [ ] **Step 5: Commit documentation**

```bash
git add docs/product/forecast-methodology.md docs/product/acceptance-criteria.md docs/product/bug-triage-and-release-blockers.md CHANGELOG.md
git commit -m "Document stable weekly forecasting"
```

This plan stops before packaging and release. Execute the reset-credit plan next, then run one combined installed-app acceptance and release checklist for `v0.3.1-beta.1`.
