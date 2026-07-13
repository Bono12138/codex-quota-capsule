# Quota Capsule Weekly Only Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `v0.2.0-beta.1` as a Weekly Only macOS runway assistant that produces trustworthy weekly pace judgments from cleaned local history and contains no user-facing 5-hour product concept.

**Architecture:** Replace the dual-window snapshot and single-point linear predictor with a weekly-only domain model. Keep raw app-server readings separate from a pure quality engine, feed accepted observations into a quantization-aware pace-band forecaster, and render one presentation model in the macOS capsule, menu bar, and TypeScript mock. Preserve current app materials and interactions while moving technical diagnostics out of the normal panel.

**Tech Stack:** Swift 6 / SwiftUI / XCTest / SQLite3, TypeScript 5 / Vitest / Vite, npm workspaces, shell packaging and GitHub Actions.

## Global Constraints

- Target release is `v0.2.0-beta.1`; `CFBundleShortVersionString` is `0.2.0`.
- Only weekly candidates within 60 minutes of 10,080 minutes are accepted; all shorter windows are ignored.
- Reserve five percentage points at reset.
- Freshness threshold is 180 seconds.
- Reset timestamps within five minutes are one cluster.
- A candidate reset requires three consecutive readings spanning at least two minutes.
- Low-confidence, stale, or unstable data cannot produce `够用`, `偏快`, or `可能不够`.
- No normal user-facing copy may contain `5 小时`, `5h`, `短窗口`, JSON-RPC, or app-server terminology.
- No new runtime dependency is added.
- All calculations remain local and no credentialed data enters fixtures, analytics, staging, or release artifacts.
- Every behavior change follows red-green-refactor and ends with a focused commit.

---

## File Map

### Create

- `Tests/QuotaCapsuleCoreTests/WeeklySourceTests.swift`: Swift parser and weekly-only source contract.
- `Tests/QuotaCapsuleCoreTests/WeeklyQualityEngineTests.swift`: reset, correction, instability, and freshness behavior.
- `Tests/QuotaCapsuleCoreTests/WeeklyRunwayPredictorTests.swift`: quantization-aware pace and state rules.
- `Tests/QuotaCapsuleCoreTests/WeeklyFixtureParityTests.swift`: shared JSON fixture runner.
- `Sources/QuotaCapsuleCore/WeeklyQualityEngine.swift`: pure raw-reading cleaner and cycle state machine.
- `Sources/QuotaCapsuleCore/WeeklyRunwayPredictor.swift`: pure pace-band and runway forecast engine.
- `Sources/QuotaCapsuleMac/WeeklyTrendView.swift`: compact current-cycle visualization.
- `fixtures/weekly-runway-cases.json`: shared Swift/TypeScript behavioral fixtures.

### Replace or substantially modify

- `Sources/QuotaCapsuleCore/Model.swift`: weekly-only source, observation, quality, confidence, and forecast types.
- `Sources/QuotaCapsuleCore/CodexRateLimitParser.swift`: select and validate only the weekly candidate.
- `Sources/QuotaCapsuleCore/CodexAppServerClient.swift`: remove weekly-only retry-as-idle behavior.
- `Sources/QuotaCapsuleCore/QuotaRefreshReducer.swift`: weekly-only stale/failure reduction.
- `Sources/QuotaCapsuleCore/CapsuleDisplayModel.swift`: Weekly Only presentation model.
- `Sources/QuotaCapsuleMac/QuotaHistoryStore.swift`: schema v3 migration, raw weekly reads, accepted-series query.
- `Sources/QuotaCapsuleMac/QuotaStore.swift`: build forecast from history and expose weekly UI values.
- `Sources/QuotaCapsuleMac/CapsuleViews.swift`: Weekly Only collapsed and expanded hierarchy.
- `Sources/QuotaCapsuleCore/QuotaLocale.swift`: new weekly copy and removal of short-window copy.
- `Sources/QuotaCapsuleCoreSpec/main.swift`: retain only smoke coverage not duplicated by XCTest.
- `Package.swift`: add the XCTest target and fixture resource.
- `packages/core/src/model.ts`, `prediction.ts`, `snapshot.ts`, `mock.ts`, `copy.ts`: Weekly Only parity.
- `packages/source-codex/src/probe.ts`: ignore short candidates.
- `apps/desktop/src/capsule-view.ts`, `main.tsx`, `styles.css`: Weekly Only mock parity.
- Existing Swift and TypeScript tests: remove obsolete 5-hour expectations.
- README, INSTALL, product docs, release docs, public manifest, analytics fields, and scripts: current-release Weekly Only truth.

### Delete

- `Sources/QuotaCapsuleCore/QuotaPredictor.swift` after all consumers move to `WeeklyRunwayPredictor`.
- Obsolete short-window test cases and user-facing copy.

---

### Task 1: Establish Weekly Only Types, XCTest, And Source Parsing

**Files:**
- Modify: `Package.swift`
- Modify: `Sources/QuotaCapsuleCore/Model.swift`
- Modify: `Sources/QuotaCapsuleCore/CodexRateLimitParser.swift`
- Modify: `Sources/QuotaCapsuleCore/CodexAppServerClient.swift`
- Create: `Tests/QuotaCapsuleCoreTests/WeeklySourceTests.swift`

**Interfaces:**
- Produces: `AgentQuotaSnapshot(provider:sourceStatus:fetchedAt:weeklyWindow:errorMessage:)`.
- Produces: `CodexRateLimitParser.parse(result:fetchedAt:locale:) -> AgentQuotaSnapshot`.
- Invariant: the returned snapshot has no short-window field.

- [ ] **Step 1: Add a discoverable XCTest target and failing parser tests**

```swift
@testable import QuotaCapsuleCore
import XCTest

final class WeeklySourceTests: XCTestCase {
    func testParserIgnoresShortWindowAndSelectsWeeklyWindow() {
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        let snapshot = CodexRateLimitParser.parse(result: [
            "rateLimits": [
                "primary": ["usedPercent": 41, "windowDurationMins": 300, "resetsAt": now.addingTimeInterval(3_600).timeIntervalSince1970],
                "secondary": ["usedPercent": 18, "windowDurationMins": 10_080, "resetsAt": now.addingTimeInterval(500_000).timeIntervalSince1970]
            ]
        ], fetchedAt: now)

        XCTAssertEqual(snapshot.sourceStatus, .ok)
        XCTAssertEqual(snapshot.weeklyWindow?.usedPercent, 18)
        XCTAssertEqual(snapshot.weeklyWindow?.windowMinutes, 10_080)
    }

    func testParserRejectsPayloadWithoutWeeklyWindow() {
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        let snapshot = CodexRateLimitParser.parse(result: [
            "rateLimits": [
                "primary": ["usedPercent": 10, "windowDurationMins": 300, "resetsAt": now.addingTimeInterval(3_600).timeIntervalSince1970]
            ]
        ], fetchedAt: now)

        XCTAssertEqual(snapshot.sourceStatus, .error)
        XCTAssertNil(snapshot.weeklyWindow)
    }
}
```

- [ ] **Step 2: Run the tests and prove the old model fails**

Run: `swift test --filter WeeklySourceTests`

Expected: compilation failure because `AgentQuotaSnapshot` still requires `shortWindow`, or assertion failure because the parser accepts the short window as a valid overall result.

- [ ] **Step 3: Implement the weekly-only source model and parser**

```swift
public struct AgentQuotaSnapshot: Equatable, Sendable {
    public let provider: String
    public let sourceStatus: SourceStatus
    public let fetchedAt: Date
    public let weeklyWindow: QuotaWindow?
    public let errorMessage: String?

    public init(provider: String, sourceStatus: SourceStatus, fetchedAt: Date, weeklyWindow: QuotaWindow?, errorMessage: String?) {
        self.provider = provider
        self.sourceStatus = sourceStatus
        self.fetchedAt = fetchedAt
        self.weeklyWindow = weeklyWindow
        self.errorMessage = errorMessage
    }
}
```

Parser selection must use `abs(window.windowMinutes - 10_080) <= 60`, validate `used + remaining` through the derived remaining value, reject expired or implausible reset times, and ignore every other duration.

- [ ] **Step 4: Remove retry logic that treats weekly-only data as incomplete**

`CodexAppServerClient.shouldRetry` returns true only for `.error` snapshots without a usable weekly window. A fresh weekly snapshot is final and successful.

- [ ] **Step 5: Run focused and full Swift checks**

Run:

```bash
swift test --filter WeeklySourceTests
swift build --product QuotaCapsuleMac
```

Expected: both commands pass.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/QuotaCapsuleCore Tests/QuotaCapsuleCoreTests/WeeklySourceTests.swift
git commit -m "Make Codex source weekly only"
```

---

### Task 2: Build The Pure Weekly Data Quality Engine

**Files:**
- Modify: `Sources/QuotaCapsuleCore/Model.swift`
- Create: `Sources/QuotaCapsuleCore/WeeklyQualityEngine.swift`
- Create: `Tests/QuotaCapsuleCoreTests/WeeklyQualityEngineTests.swift`

**Interfaces:**
- Consumes: `[WeeklyQuotaReading]` ordered by `fetchedAt`.
- Produces: `WeeklyQualityResult(state:observations:canonicalResetAt:flags:)`.
- Produces only accepted monotone observation segments for forecasting.

- [ ] **Step 1: Write failing tests for jitter, reset confirmation, corrections, and alternating streams**

```swift
func testSecondLevelResetJitterStaysInOneCycle() {
    let result = WeeklyQualityEngine.analyze([
        reading(minute: 0, used: 10, resetOffset: 500_000),
        reading(minute: 1, used: 10, resetOffset: 500_001),
        reading(minute: 2, used: 11, resetOffset: 499_999)
    ])
    XCTAssertEqual(result.state, .stable)
    XCTAssertEqual(Set(result.observations.map(\.cycleID)).count, 1)
}

func testAlternatingOneAndFivePercentCalibrates() {
    let result = WeeklyQualityEngine.analyze([
        reading(minute: 0, used: 1, resetOffset: 500_000),
        reading(minute: 1, used: 5, resetOffset: 500_070),
        reading(minute: 2, used: 1, resetOffset: 500_000),
        reading(minute: 3, used: 5, resetOffset: 500_070),
        reading(minute: 4, used: 1, resetOffset: 500_000)
    ])
    XCTAssertEqual(result.state, .unstable)
    XCTAssertTrue(result.flags.contains(.alternatingStream))
}
```

- [ ] **Step 2: Run and verify red**

Run: `swift test --filter WeeklyQualityEngineTests`

Expected: compilation failure because `WeeklyQualityEngine` does not exist.

- [ ] **Step 3: Implement quality types and deterministic state machine**

```swift
public enum WeeklyQualityState: String, Codable, Sendable { case stable, calibrating, unstable, stale, unavailable }
public enum WeeklyQualityFlag: String, Codable, Hashable, Sendable { case resetCandidate, correction, alternatingStream, resetJitter, staleSource }

public enum WeeklyQualityEngine {
    public static let resetClusterTolerance: TimeInterval = 300
    public static let freshnessThreshold: TimeInterval = 180
    public static func analyze(_ readings: [WeeklyQuotaReading], now: Date = Date()) -> WeeklyQualityResult {
        let ordered = readings.sorted { $0.fetchedAt < $1.fetchedAt }
        guard let latest = ordered.last else { return .unavailable }
        guard now.timeIntervalSince(latest.fetchedAt) <= freshnessThreshold else {
            return .stale(lastReading: latest)
        }
        let buckets = fiveMinuteRepresentatives(ordered)
        let alternation = detectAlternation(in: Array(buckets.suffix(5)))
        guard !alternation else {
            return .unstable(lastReading: latest, flags: [.alternatingStream])
        }
        return buildAcceptedSegments(
            from: buckets,
            resetTolerance: resetClusterTolerance,
            confirmationCount: 3,
            confirmationSpan: 120,
            correctionDrop: 2
        )
    }
}
```

The implementation must be pure, deterministic, non-throwing, and must not access SQLite or locale copy.

- [ ] **Step 4: Add edge tests for stale data, single negative readings, stable lower corrections, and manual resets**

Expected assertions:

- stale latest reading returns `.stale`;
- one lower reading does not change the accepted segment;
- three stable lower readings create a new segment with `.correction`;
- three readings with a later reset cluster and usage drop create a new cycle.

- [ ] **Step 5: Run focused tests and commit**

```bash
swift test --filter WeeklyQualityEngineTests
git add Sources/QuotaCapsuleCore/Model.swift Sources/QuotaCapsuleCore/WeeklyQualityEngine.swift Tests/QuotaCapsuleCoreTests/WeeklyQualityEngineTests.swift
git commit -m "Add weekly quota quality engine"
```

---

### Task 3: Implement Quantization-Aware Weekly Runway Forecasting

**Files:**
- Create: `Sources/QuotaCapsuleCore/WeeklyRunwayPredictor.swift`
- Create: `Tests/QuotaCapsuleCoreTests/WeeklyRunwayPredictorTests.swift`
- Delete after migration: `Sources/QuotaCapsuleCore/QuotaPredictor.swift`

**Interfaces:**
- Consumes: `AgentQuotaSnapshot`, `WeeklyQualityResult`, and `now`.
- Produces: `WeeklyRunwayForecast` with confidence, pace bands, budget, projection band, and state.

- [ ] **Step 1: Write failing tests for sustainable rate, flat precision, and state ordering**

```swift
func testSustainableRateLeavesFivePercentReserve() {
    let forecast = predict(remaining: 65, daysRemaining: 4, observations: stableDailySteps([0, 10, 20]))
    XCTAssertEqual(forecast.sustainableRatePerDay, 15, accuracy: 0.001)
}

func testFlatIntegerReadingsDoNotClaimZeroPace() {
    let forecast = predict(remaining: 99, daysRemaining: 6, observations: flatReadings(value: 1, hours: 8))
    XCTAssertEqual(forecast.state, .calibrating)
    XCTAssertNil(forecast.recentRateBandPerDay)
}

func testBothPaceScenariosRunningOutIsMayRunOut() {
    let forecast = predict(remaining: 20, daysRemaining: 3, observations: stableDailySteps([50, 60, 70, 80]))
    XCTAssertEqual(forecast.state, .mayRunOut)
}
```

- [ ] **Step 2: Run and verify red**

Run: `swift test --filter WeeklyRunwayPredictorTests`

Expected: compilation failure because `WeeklyRunwayPredictor` and forecast types do not exist.

- [ ] **Step 3: Implement interval and robust-slope math**

```swift
public struct PaceBand: Equatable, Codable, Sendable {
    public let lower: Double
    public let upper: Double
}

public enum WeeklyRunwayPredictor {
    public static let reservePercent = 5.0
    public static func predict(snapshot: AgentQuotaSnapshot, quality: WeeklyQualityResult, now: Date = Date(), locale: QuotaLocale = .zhHans) -> WeeklyRunwayForecast {
        guard snapshot.sourceStatus == .ok, let window = snapshot.weeklyWindow else {
            return .unavailable(snapshot: snapshot, locale: locale)
        }
        guard quality.state == .stable else {
            return .calibrating(snapshot: snapshot, quality: quality, locale: locale)
        }
        if window.remainingPercent <= 0 {
            return .exhausted(snapshot: snapshot, locale: locale)
        }
        let daysRemaining = window.resetsAt.timeIntervalSince(now) / 86_400
        let sustainable = max(0, window.remainingPercent - reservePercent) / daysRemaining
        let cycle = robustPaceBand(quality.observations)
        let recent = robustPaceBand(quality.observations.filter { now.timeIntervalSince($0.fetchedAt) <= 86_400 })
        guard let cycle, let recent else {
            return .calibrating(snapshot: snapshot, quality: quality, locale: locale)
        }
        let combined = PaceBand(lower: min(cycle.lower, recent.lower), upper: max(cycle.upper, recent.upper))
        return buildForecast(snapshot: snapshot, quality: quality, pace: combined, sustainable: sustainable, daysRemaining: daysRemaining, locale: locale)
    }
}
```

Use interval endpoints for integer readings, pair samples at least 30 minutes apart, trim outside three median absolute deviations when at least five slopes exist, and take median lower/upper slopes. Never divide by zero or display non-finite values.

- [ ] **Step 4: Add tests for disagreement, recent acceleration, exhaustion, and invariants**

Include tests proving:

- one optimistic and one pessimistic scenario gives `.runningFast`;
- pessimistic remaining at least 5 gives `.onTrack`;
- remaining zero gives `.exhausted` before calibration checks;
- more usage cannot improve projected remaining;
- less remaining time cannot increase the next-24-hour budget.

- [ ] **Step 5: Run focused tests and commit**

```bash
swift test --filter WeeklyRunwayPredictorTests
git add Sources/QuotaCapsuleCore Tests/QuotaCapsuleCoreTests/WeeklyRunwayPredictorTests.swift
git commit -m "Add weekly runway forecasting"
```

---

### Task 4: Migrate Local History And Feed Clean Observations Into Forecasting

**Files:**
- Modify: `Sources/QuotaCapsuleMac/QuotaHistoryStore.swift`
- Modify: `Sources/QuotaCapsuleMac/QuotaStore.swift`
- Modify: `Sources/QuotaCapsuleCore/QuotaRefreshReducer.swift`
- Add focused storage tests under `Tests/QuotaCapsuleCoreTests` for pure migration helpers; exercise SQLite with the macOS spec executable.

**Interfaces:**
- Produces: `QuotaHistoryStore.recentWeeklyReadings(limit:) -> [WeeklyQuotaReading]`.
- `QuotaStore` records the latest raw weekly reading, reads history, runs quality, then forecasting.

- [ ] **Step 1: Write failing migration and history tests**

Test a schema-v2 database containing weekly and `5h` rows. After migration:

- history schema version is 3;
- zero `5h` rows remain;
- valid weekly rows remain queryable;
- old derived rate and reset fields are not consumed.

- [ ] **Step 2: Run the storage spec and verify red**

Run: `swift run QuotaCapsuleCoreSpec`

Expected: failure from the new migration assertions.

- [ ] **Step 3: Implement idempotent schema-v3 migration and raw weekly query**

```swift
static let historySchemaVersion = 3

func recentWeeklyReadings(limit: Int = 2_500) -> [WeeklyQuotaReading] {
    let sql = """
    SELECT c.fetched_at, w.window_minutes, w.used_percent, w.remaining_percent, w.resets_at
    FROM quota_windows w
    JOIN captures c ON c.id = w.capture_id
    WHERE w.window_type = 'weekly'
    ORDER BY c.fetched_at DESC
    LIMIT ?
    """
    return queryWeeklyReadings(sql: sql, limit: limit).reversed()
}
```

Migration deletes `window_type='5h'`, preserves structurally valid weekly raw columns, and clears or ignores legacy derived fields. Run it in a transaction and make repeated launches safe.

- [ ] **Step 4: Integrate refresh, history, quality, and forecast in QuotaStore**

Order on successful refresh:

1. reduce source result;
2. persist raw weekly reading;
3. load recent weekly readings;
4. analyze quality;
5. calculate forecast;
6. publish one display model on the main actor.

On failure, freeze the last successful reading and forecast inputs; do not advance elapsed progress using the current clock.

- [ ] **Step 5: Run focused storage, reducer, and full Swift checks**

```bash
swift run QuotaCapsuleCoreSpec
swift test
swift build --product QuotaCapsuleMac
```

- [ ] **Step 6: Commit**

```bash
git add Sources/QuotaCapsuleMac/QuotaHistoryStore.swift Sources/QuotaCapsuleMac/QuotaStore.swift Sources/QuotaCapsuleCore/QuotaRefreshReducer.swift Sources/QuotaCapsuleCoreSpec/main.swift
git commit -m "Drive forecasts from cleaned weekly history"
```

---

### Task 5: Replace Presentation Copy And Display Model

**Files:**
- Modify: `Sources/QuotaCapsuleCore/CapsuleDisplayModel.swift`
- Modify: `Sources/QuotaCapsuleCore/QuotaLocale.swift`
- Modify: `Sources/QuotaCapsuleMac/StatusBarController.swift`
- Modify: `Sources/QuotaCapsuleMac/FeedbackSupport.swift`
- Test: `Tests/QuotaCapsuleCoreTests/WeeklyRunwayPredictorTests.swift`

**Interfaces:**
- Produces: one `CapsuleDisplayModel` containing state label, forecast sentence, dual progress, budget metrics, freshness, and confidence text.

- [ ] **Step 1: Write failing copy and display tests in all locales**

```swift
func testOnTrackChineseDisplayIsWeeklyAndActionable() {
    let model = CapsuleDisplayModel.make(forecast: .fixtureOnTrack, locale: .zhHans)
    XCTAssertEqual(model.statusLabel, "够用")
    XCTAssertTrue(model.defaultText.contains("刷新时预计剩"))
    XCTAssertFalse(model.defaultText.contains("5 小时"))
    XCTAssertEqual(model.metrics.map(\.label), ["本周时间", "本周已用", "最近 24 小时", "未来 24 小时建议"])
}
```

- [ ] **Step 2: Run and verify red**

Run: `swift test --filter WeeklyRunwayPredictorTests`

- [ ] **Step 3: Implement copy and presentation mapping**

Map `.onTrack`, `.runningFast`, `.mayRunOut`, `.calibrating`, `.exhausted`, and `.unavailable` to the approved wording. Formatting functions accept optional ranges and never format NaN, infinity, or negative displayed percentages.

- [ ] **Step 4: Remove short-window copy and diagnostic leakage**

Delete obsolete onboarding, tooltip, status-bar, feedback, and help strings. Data-source terminology remains only in diagnostic copy.

- [ ] **Step 5: Run copy search and tests**

```bash
swift test
rg -n "5 小时|5h|短窗口|等待新的" Sources apps packages README*.md INSTALL.md docs/product
```

Expected: no current user-facing matches; allowed historical/spec references are reviewed explicitly.

- [ ] **Step 6: Commit**

```bash
git add Sources/QuotaCapsuleCore Sources/QuotaCapsuleMac Tests
git commit -m "Present weekly runway decisions"
```

---

### Task 6: Rebuild The Native Capsule Around Weekly Runway

**Files:**
- Modify: `Sources/QuotaCapsuleMac/CapsuleViews.swift`
- Create: `Sources/QuotaCapsuleMac/WeeklyTrendView.swift`
- Modify: `Sources/QuotaCapsuleMac/QuotaStore.swift`

**Interfaces:**
- Consumes only `CapsuleDisplayModel` and chart points from QuotaStore.
- Produces collapsed, expanded, calibrating, stale, unavailable, and exhausted Weekly Only surfaces.

- [ ] **Step 1: Add deterministic mock states for every user-visible condition**

Create debug fixtures for on-track, running-fast, may-run-out, calibrating, stale, unavailable, and exhausted states. Each fixture supplies realistic percentages, reset times, budgets, confidence, and chart points.

- [ ] **Step 2: Build and capture the old UI as the expected failing visual baseline**

Run: `npm run mac:run:dev`

Expected: the app still shows the old 5-hour hierarchy and fails the new visual acceptance checklist.

- [ ] **Step 3: Implement the collapsed Weekly Only hierarchy**

Standard width renders state + used percent, one forecast sentence, and time/usage bars. Narrow width renders state + used percent and one sentence. Preserve dragging, resizing, hover, expand/collapse, and menu-bar behavior.

- [ ] **Step 4: Implement the expanded hierarchy and trend**

Render in approved order: hero, dual progress, recent/budget pair, compact trend, freshness/confidence, actions. Move source pills into the diagnostics sheet or menu. Use SwiftUI drawing primitives and existing colors; add no chart dependency.

- [ ] **Step 5: Verify accessibility and all mock states with Computer Use**

For each state, capture current-run screenshots at standard and narrow widths. Check contrast, 11-point minimum essential text, no clipping, text-plus-color state communication, keyboard access, and menu-bar consistency.

- [ ] **Step 6: Run builds and commit**

```bash
swift test
swift build --product QuotaCapsuleMac
git add Sources/QuotaCapsuleMac
git commit -m "Redesign capsule for weekly runway"
```

---

### Task 7: Align TypeScript, Shared Fixtures, And Browser Mock

**Files:**
- Create: `fixtures/weekly-runway-cases.json`
- Modify: `packages/core/src/model.ts`
- Modify: `packages/core/src/prediction.ts`
- Modify: `packages/core/src/snapshot.ts`
- Modify: `packages/core/src/mock.ts`
- Modify: `packages/core/src/copy.ts`
- Modify: `packages/source-codex/src/probe.ts`
- Modify: `packages/core/test/*.test.ts`
- Modify: `packages/source-codex/test/*.test.ts`
- Modify: `apps/desktop/src/capsule-view.ts`, `main.tsx`, `styles.css`, and tests
- Create: `Tests/QuotaCapsuleCoreTests/WeeklyFixtureParityTests.swift`

**Interfaces:**
- JSON fixture dates are ISO-8601 and outputs contain exact numeric bands and state identifiers.
- Swift and TypeScript parse the same cases.

- [ ] **Step 1: Add failing shared cases**

Fixture cases include weekly-only success, ignored short candidate, flat 0%, reset jitter, manual reset, 1%/5% alternation, stale data, recent acceleration, disagreement, and exhaustion.

- [ ] **Step 2: Run both suites and verify red**

```bash
npm test
swift test --filter WeeklyFixtureParityTests
```

- [ ] **Step 3: Port Weekly Only model, quality, and forecast behavior to TypeScript**

Use the same constants, ordering, interval math, state identifiers, and fixture results. `createSnapshotRecord` records the weekly window only. The Codex probe ignores short windows.

- [ ] **Step 4: Rebuild browser mock around the same display hierarchy**

The browser mock is not a second product design. It mirrors the native Weekly Only information hierarchy and state language.

- [ ] **Step 5: Run parity, lint, build, and commit**

```bash
npm test
npm run lint
npm run build
swift test --filter WeeklyFixtureParityTests
git add fixtures packages apps Tests/QuotaCapsuleCoreTests/WeeklyFixtureParityTests.swift
git commit -m "Align weekly runway across runtimes"
```

---

### Task 8: Remove Obsolete Product Surface And Update Release Truth

**Files:**
- Modify: `README.md`, `README.zh-CN.md`, `README.en.md`, `INSTALL.md`
- Modify: `docs/product/*.md`, relevant `docs/distribution/*.md`, and `docs/decisions` only where current release behavior is stated.
- Modify: analytics event properties and tests.
- Modify: `script/build_and_run.sh` version default.
- Modify: public repository manifest if needed.

**Interfaces:**
- Current-release docs describe Weekly Only behavior exactly.
- Historical decision/spec documents may retain context but are not presented as shipped behavior.

- [ ] **Step 1: Add a failing current-surface copy audit**

Run a script or test that enumerates current-release files and fails on forbidden user-facing terms. Exclude `docs/superpowers/specs`, `docs/superpowers/plans`, and explicit historical migration notes.

- [ ] **Step 2: Update docs, onboarding claims, analytics, and version**

Set packaging default to `0.2.0`, remove short-window analytics properties, and document Weekly Only runway, forecast ranges, calibration, privacy, and diagnostics.

- [ ] **Step 3: Run public staging audit early**

```bash
npm run public:prepare
sed -n '1,260p' artifacts/public-repo-staging/PUBLIC_STAGING_AUDIT.md
```

Expected: no private files, stale current-release copy, or forbidden short-window product claims.

- [ ] **Step 4: Run documentation links/copy checks and commit**

```bash
git diff --check
rg -n "5 小时|5h|短窗口|等待新的" README*.md INSTALL.md docs/product Sources apps packages
git add README*.md INSTALL.md docs script packages Sources apps
git commit -m "Document Weekly Only beta"
```

---

### Task 9: Release-Candidate Verification In Dev Local And Beta

**Files:**
- No source changes unless a failing check reveals a bug; each bug returns to a new failing test before a fix.
- Save screenshots and audit evidence under ignored `artifacts/audits/weekly-only-v0.2.0-beta.1/`.

**Interfaces:**
- Produces verified Dev Local and Beta app bundles from the committed tree.

- [ ] **Step 1: Run the complete automated gate**

```bash
npm test
npm run lint
npm run build
swift test
npm run mac:spec
swift build --product QuotaCapsuleMac
git diff --check
```

Expected: every command passes with non-zero test counts for both Swift and TypeScript.

- [ ] **Step 2: Package and sign both channels**

```bash
npm run mac:package:dev
npm run mac:package:internal-test
codesign --verify --deep --strict --verbose=2 "dist/development/Quota Capsule Dev Local.app"
codesign --verify --deep --strict --verbose=2 "dist/internal-test/Quota Capsule Beta.app"
```

- [ ] **Step 3: Install and inspect Dev Local first**

Launch Dev Local, verify live weekly source, cleaned-series state, collapsed/expanded UI, diagnostics, refresh, stale simulation, and every deterministic mock. If any check fails, write a regression test before changing code.

- [ ] **Step 4: Install and inspect Beta from `/Applications`**

Run the repository's internal-test install command, confirm the running executable path, bundle ID, version `0.2.0`, channel, data directory, feedback routing, and analytics configuration. Capture collapsed and expanded screenshots from the installed Beta process.

- [ ] **Step 5: Audit from an anxious user's perspective**

Verify that a user can answer within five seconds:

- whether the week is enough;
- how much is used;
- when reset occurs;
- what the next-24-hour budget is;
- whether the app is calibrating or using stale data.

Reject the release if technical details compete with those answers.

- [ ] **Step 6: Commit any test-driven corrections, then freeze the candidate**

Run the full automated gate again after the last correction. The candidate commit must have a clean worktree.

---

### Task 10: Public Sync, GitHub Review, Tag, Release, And Final Verification

**Files:**
- Generated/reviewed: `artifacts/public-repo-staging/`, `artifacts/public-repo-sync/`
- Update: release notes and version metadata required by the existing release flow.

**Interfaces:**
- Produces public `main`, passing GitHub Actions, tag `v0.2.0-beta.1`, and a launchable installed Beta app.

- [ ] **Step 1: Prepare and review public staging**

```bash
npm run public:prepare
sed -n '1,320p' artifacts/public-repo-staging/PUBLIC_STAGING_AUDIT.md
```

Inspect every excluded/private item and all version/copy warnings. Do not sync on an unresolved warning.

- [ ] **Step 2: Sync reviewed staging and test it independently**

```bash
rsync -a --delete --exclude='.git' --exclude='PUBLIC_STAGING_AUDIT.md' artifacts/public-repo-staging/ artifacts/public-repo-sync/
cd artifacts/public-repo-sync
npm ci
npm test
npm run lint
npm run build
swift test
npm run mac:spec
```

- [ ] **Step 3: Request final code review and resolve every actionable finding with TDD**

Review source, tests, migration, UI states, privacy, release scripts, and diff scope. Any accepted defect first receives a failing regression test.

- [ ] **Step 4: Publish public source**

Commit the reviewed public sync, push public `main`, and confirm the remote commit matches the tested tree. Never force-push over unrelated upstream work.

- [ ] **Step 5: Confirm GitHub Actions**

Inspect every required check. If a check fails, diagnose the job logs, reproduce locally when possible, add a regression test, fix, and rerun.

- [ ] **Step 6: Create beta tag and GitHub release**

Create `v0.2.0-beta.1` only on the verified public commit. Release notes explain Weekly Only positioning, forecast ranges, calibration behavior, migration, installation, privacy, known limitations, and feedback route.

- [ ] **Step 7: Final installed-product verification**

Launch `/Applications/Quota Capsule Beta.app`, confirm version and commit provenance, run a live refresh, inspect collapsed and expanded Weekly Only states, and confirm no 5-hour copy remains.

- [ ] **Step 8: Report the release**

Return the public commit, PR/review links if used, Actions result, tag/release URL, installed app version/path, automated test counts, UI evidence paths, and any explicitly deferred limitations.
