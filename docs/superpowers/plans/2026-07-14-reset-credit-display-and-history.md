# Reset Credit Display and Local History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read the supported reset-credit details, list every available credit at the bottom of the expanded panel with minute-precise local expiry, and retain a privacy-safe local lifecycle history.

**Architecture:** Extend the existing provider-neutral snapshot with a bank summary whose count and optional details preserve upstream completeness semantics. Hash the opaque backend ID immediately, store only the hash and safe fields in SQLite, coalesce identical observations, and infer expiry/redemption conservatively. The UI reads current credits from the accepted snapshot; historical rows remain local and never enter analytics.

**Tech Stack:** Swift 6, Foundation, CryptoKit, SQLite3, Swift Testing, SwiftUI, TypeScript 5, Node crypto, Vitest

## Global Constraints

- Execute after `2026-07-14-forecast-stability-and-menu.md`; it supplies the macOS test target.
- Target release is `v0.3.1-beta.1`.
- Every normal expiry row uses the Mac's local time zone and displays through minutes, not seconds.
- The reset-credit section is the final section in the expanded panel and is absent from the collapsed capsule/menu-bar title.
- `availableCount` is authoritative; `credits == nil`, an empty list, and a capped list are different states.
- Raw opaque IDs, descriptions, referral metadata, and personal timestamps are not logged, uploaded, or committed.
- Only a one-way SHA-256 fingerprint may be persisted for deduplication.
- Reset-credit history is local-only, has no automatic pruning, and is deleted by `清除本地历史`.
- The application remains read-only and cannot redeem or schedule a reset.
- Commits use `Bono12138 <Bono12138@users.noreply.github.com>` with no co-author trailers.

---

## File structure

- `Sources/QuotaCapsuleCore/Model.swift`: provider-neutral bank and credit values.
- `Sources/QuotaCapsuleCore/CodexRateLimitParser.swift`: safe parsing, hashing, validation, and sort order.
- `Sources/QuotaCapsuleCore/QuotaRefreshReducer.swift`: preserves the last successful bank across stale reads and confirmation.
- `Tests/QuotaCapsuleCoreTests/WeeklySourceTests.swift`: Swift source-schema regressions.
- `packages/core/src/model.ts`: TypeScript bank and credit values.
- `packages/source-codex/src/probe.ts`: TypeScript parsing and SHA-256 hashing.
- `packages/source-codex/test/rate-limits.test.ts`: TypeScript source-schema regressions.
- `Sources/QuotaCapsuleCore/ResetCreditHistory.swift`: lifecycle types and conservative inference rules.
- `Tests/QuotaCapsuleCoreTests/ResetCreditHistoryTests.swift`: pure lifecycle tests.
- `Sources/QuotaCapsuleMac/QuotaHistoryStore.swift`: SQLite schema, upsert/coalescing, queries, and clear-history integration.
- `Tests/QuotaCapsuleMacTests/ResetCreditPersistenceTests.swift`: temporary-database integration tests.
- `Sources/QuotaCapsuleCore/QuotaLocale.swift`: bank and expiry copy.
- `Sources/QuotaCapsuleMac/QuotaStore.swift`: footer presentation rows and history recording.
- `Sources/QuotaCapsuleMac/CapsuleViews.swift`: bottom-of-panel reset-credit footer.
- `Tests/QuotaCapsuleCoreTests/WeeklyDisplayModelTests.swift`: locale/time formatting regressions.
- `docs/product/forecast-methodology.md`: reset credits remain separate from pace evidence.
- `docs/product/acceptance-criteria.md`: count/detail/privacy/history acceptance.
- `docs/product/mvp-scope.md`: read-only reset-credit boundary.
- `CHANGELOG.md`: visible feature and privacy notes.

---

### Task 1: Add provider-neutral reset-credit parsing in Swift and TypeScript

**Files:**
- Modify: `Sources/QuotaCapsuleCore/Model.swift`
- Modify: `Sources/QuotaCapsuleCore/CodexRateLimitParser.swift`
- Modify: `Sources/QuotaCapsuleCore/QuotaRefreshReducer.swift`
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklySourceTests.swift`
- Modify: `packages/core/src/model.ts`
- Modify: `packages/source-codex/src/probe.ts`
- Modify: `packages/source-codex/test/rate-limits.test.ts`

**Interfaces:**
- Produces: `ResetCredit`, `ResetCreditBankSummary`, `ResetCreditStatus`, `ResetCreditGrantTimeSource`, and `ResetCreditDetailState` in both languages.
- Extends: `AgentQuotaSnapshot.resetCreditBank` / `resetCreditBank?`.

- [ ] **Step 1: Add failing Swift parser tests**

Add a test payload with fake IDs only:

```swift
@Test("reset credit details preserve count, nullable expiry, and safe identity")
func parserReadsResetCreditBank() throws {
    let snapshot = CodexRateLimitParser.parse(
        result: [
            "rateLimits": ["primary": window(used: 18, minutes: 10_080, resetOffset: 500_000)],
            "rateLimitResetCredits": [
                "availableCount": 3,
                "credits": [
                    [
                        "id": "fake-credit-a",
                        "resetType": "codexRateLimits",
                        "status": "available",
                        "grantedAt": now.timeIntervalSince1970 - 86_400,
                        "expiresAt": now.timeIntervalSince1970 + 86_400,
                        "title": "Full reset",
                        "description": "must be ignored"
                    ],
                    [
                        "id": "fake-credit-b",
                        "resetType": "codexRateLimits",
                        "status": "unknown",
                        "grantedAt": now.timeIntervalSince1970 - 43_200,
                        "expiresAt": NSNull(),
                        "title": NSNull(),
                        "description": NSNull()
                    ]
                ]
            ]
        ],
        fetchedAt: now
    )

    let bank = try #require(snapshot.resetCreditBank)
    #expect(bank.availableCount == 3)
    #expect(bank.fetchedAt == now)
    #expect(bank.detailState == .capped)
    #expect(bank.credits?.count == 2)
    #expect(bank.credits?.first?.fingerprint.count == 64)
    #expect(bank.credits?.first?.fingerprint != "fake-credit-a")
    #expect(bank.credits?.last?.expiresAt == nil)
}
```

Add separate cases for `credits: NSNull()`, `credits: []`, missing/null grant time, invalid non-null grant time, invalid non-null expiry, and a missing bank field. A missing/null grant time is retained as unknown; a malformed non-null time rejects only that detail row.

- [ ] **Step 2: Add equivalent failing TypeScript parser tests**

Assert:

```ts
expect(parsed.resetCreditBank?.availableCount).toBe(3);
expect(parsed.resetCreditBank?.detailState).toBe("capped");
expect(parsed.resetCreditBank?.credits?.[0].fingerprint).toMatch(/^[0-9a-f]{64}$/);
expect(parsed.resetCreditBank?.credits?.[0]).not.toHaveProperty("id");
expect(parsed.resetCreditBank?.credits?.[0]).not.toHaveProperty("description");
expect(parsed.resetCreditBank?.credits?.[1].expiresAt).toBeNull();
```

- [ ] **Step 3: Run focused suites and verify missing model fields**

Run:

```bash
swift test --filter WeeklySourceTests
npx vitest run packages/source-codex/test/rate-limits.test.ts
```

Expected: FAIL because reset-credit values do not exist.

- [ ] **Step 4: Add exact Swift domain types**

Add:

```swift
public enum ResetCreditStatus: String, Codable, Equatable, Sendable {
    case available
    case redeeming
    case redeemed
    case unknown
}

public enum ResetCreditDetailState: String, Codable, Equatable, Sendable {
    case countOnly
    case complete
    case capped
}

public enum ResetCreditGrantTimeSource: String, Codable, Equatable, Sendable {
    case provider
    case inferredExpiryMinus30Days
    case unknown
}

public struct ResetCredit: Equatable, Sendable {
    public let fingerprint: String
    public let resetType: String
    public let status: ResetCreditStatus
    public let grantedAt: Date?
    public let grantTimeSource: ResetCreditGrantTimeSource
    public let expiresAt: Date?
    public let title: String?

    public init(
        fingerprint: String,
        resetType: String,
        status: ResetCreditStatus,
        grantedAt: Date?,
        grantTimeSource: ResetCreditGrantTimeSource,
        expiresAt: Date?,
        title: String?
    ) {
        self.fingerprint = fingerprint
        self.resetType = resetType
        self.status = status
        self.grantedAt = grantedAt
        self.grantTimeSource = grantTimeSource
        self.expiresAt = expiresAt
        self.title = title
    }
}

public struct ResetCreditBankSummary: Equatable, Sendable {
    public let availableCount: Int
    public let credits: [ResetCredit]?
    public let detailState: ResetCreditDetailState
    public let fetchedAt: Date

    public init(
        availableCount: Int,
        credits: [ResetCredit]?,
        detailState: ResetCreditDetailState,
        fetchedAt: Date
    ) {
        self.availableCount = availableCount
        self.credits = credits
        self.detailState = detailState
        self.fetchedAt = fetchedAt
    }
}
```

Add `resetCreditBank: ResetCreditBankSummary? = nil` to the `AgentQuotaSnapshot` initializer so existing call sites remain source-compatible.

- [ ] **Step 5: Parse, validate, hash, and sort in Swift**

Import CryptoKit and hash only the opaque ID:

```swift
private static func fingerprint(_ rawID: String) -> String {
    SHA256.hash(data: Data(rawID.utf8)).map { String(format: "%02x", $0) }.joined()
}
```

Validation rules:

- integer `availableCount` in `0...1_000_000`;
- mandatory non-empty ID and reset type, plus valid status fallback to `.unknown`;
- missing/null `grantedAt` becomes `nil` with `.unknown` source; a present value must fall between 2000-01-01 and 2100-01-01 and is labelled `.provider`;
- `expiresAt == null` is valid; a present non-null invalid timestamp rejects that detail row;
- title is trimmed, empty becomes nil, and length is capped at 120 characters;
- description is never copied;
- expiring credits sort first by expiry, then known grant time, then fingerprint; non-expiring credits and unknown grant times sort last within their respective group.

Retain validated rows for local status history, but only `.available` rows are eligible for the normal footer. Set detail state to `countOnly` for `credits == null`, `capped` when the number of validated `.available` rows is less than `availableCount`, otherwise `complete`.

- [ ] **Step 6: Mirror types and parser in TypeScript**

Use Node's `createHash`:

```ts
import { createHash } from "node:crypto";

function resetCreditFingerprint(rawId: string): string {
  return createHash("sha256").update(rawId, "utf8").digest("hex");
}
```

Apply the same validation, nullable details, capped-state, title limit, and sort order.

- [ ] **Step 7: Preserve bank state through stale and confirmation reducers**

When a successful snapshot becomes stale, copy `currentSnapshot.resetCreditBank`. When an unconfirmed weekly reset keeps the previous weekly window, keep the previous accepted bank in the visible snapshot while `latestAttemptSnapshot` retains the newly read bank for history.

- [ ] **Step 8: Run tests and commit**

Run:

```bash
swift test --filter WeeklySourceTests
npx vitest run packages/source-codex/test/rate-limits.test.ts packages/source-codex/test/app-server.test.ts
npm run build -w packages/core
npm run build -w packages/source-codex
```

Expected: PASS.

Commit:

```bash
git add Sources/QuotaCapsuleCore/Model.swift Sources/QuotaCapsuleCore/CodexRateLimitParser.swift Sources/QuotaCapsuleCore/QuotaRefreshReducer.swift Tests/QuotaCapsuleCoreTests/WeeklySourceTests.swift packages/core/src/model.ts packages/source-codex/src/probe.ts packages/source-codex/test/rate-limits.test.ts
git commit -m "Read reset credit details safely"
```

---

### Task 2: Persist reset-credit lifecycle history locally

**Files:**
- Create: `Sources/QuotaCapsuleCore/ResetCreditHistory.swift`
- Create: `Tests/QuotaCapsuleCoreTests/ResetCreditHistoryTests.swift`
- Modify: `Sources/QuotaCapsuleMac/QuotaHistoryStore.swift`
- Create: `Tests/QuotaCapsuleMacTests/ResetCreditPersistenceTests.swift`
- Modify: `Sources/QuotaCapsuleMac/QuotaStore.swift`

**Interfaces:**
- Produces: `ResetCreditLifecycle` and conservative disappearance classification.
- Produces: `QuotaHistoryStore.recordResetCreditBank`, `resetCreditHistory`, and `confirmLikelyResetCreditRedemption`.
- Produces: `ResetCreditHistoryRecord` and `ResetCreditBankRun` query values for tests and future local statistics.

- [ ] **Step 1: Add failing lifecycle tests**

Create:

```swift
@testable import QuotaCapsuleCore
import Foundation
import Testing

@Suite("Reset credit lifecycle")
struct ResetCreditHistoryTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("a disappearance after expiry is expired")
    func expiredDisappearance() {
        #expect(ResetCreditLifecycleClassifier.classifyDisappearance(
            expiresAt: now.addingTimeInterval(-1),
            observedAt: now,
            compatibleResetConfirmed: false
        ) == .expired)
    }

    @Test("a pre-expiry disappearance needs reset confirmation")
    func earlyDisappearanceIsConservative() {
        let expiry = now.addingTimeInterval(86_400)
        #expect(ResetCreditLifecycleClassifier.classifyDisappearance(
            expiresAt: expiry,
            observedAt: now,
            compatibleResetConfirmed: false
        ) == .disappearedUnknown)
        #expect(ResetCreditLifecycleClassifier.classifyDisappearance(
            expiresAt: expiry,
            observedAt: now,
            compatibleResetConfirmed: true
        ) == .likelyRedeemed)
    }
}
```

- [ ] **Step 2: Implement pure lifecycle types**

Add:

```swift
public enum ResetCreditLifecycle: String, Codable, Equatable, Sendable {
    case available
    case expired
    case likelyRedeemed
    case disappearedUnknown
}

public enum ResetCreditLifecycleClassifier {
    public static func classifyDisappearance(
        expiresAt: Date?,
        observedAt: Date,
        compatibleResetConfirmed: Bool
    ) -> ResetCreditLifecycle {
        if let expiresAt, expiresAt <= observedAt { return .expired }
        return compatibleResetConfirmed ? .likelyRedeemed : .disappearedUnknown
    }
}

public struct ResetCreditHistoryRecord: Equatable, Sendable {
    public let fingerprint: String
    public let resetType: String
    public let safeTitle: String?
    public let grantedAt: Date?
    public let grantTimeSource: ResetCreditGrantTimeSource
    public let expiresAt: Date?
    public let firstSeenAt: Date
    public let lastSeenAt: Date
    public let latestStatus: ResetCreditStatus
    public let lifecycle: ResetCreditLifecycle
    public let sampleCount: Int

    public init(
        fingerprint: String,
        resetType: String,
        safeTitle: String?,
        grantedAt: Date?,
        grantTimeSource: ResetCreditGrantTimeSource,
        expiresAt: Date?,
        firstSeenAt: Date,
        lastSeenAt: Date,
        latestStatus: ResetCreditStatus,
        lifecycle: ResetCreditLifecycle,
        sampleCount: Int
    ) {
        self.fingerprint = fingerprint
        self.resetType = resetType
        self.safeTitle = safeTitle
        self.grantedAt = grantedAt
        self.grantTimeSource = grantTimeSource
        self.expiresAt = expiresAt
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.latestStatus = latestStatus
        self.lifecycle = lifecycle
        self.sampleCount = sampleCount
    }
}

public struct ResetCreditBankRun: Equatable, Sendable {
    public let signature: String
    public let firstObservedAt: Date
    public let lastObservedAt: Date
    public let sampleCount: Int
    public let availableCount: Int
    public let detailCount: Int?
    public let detailState: ResetCreditDetailState

    public init(
        signature: String,
        firstObservedAt: Date,
        lastObservedAt: Date,
        sampleCount: Int,
        availableCount: Int,
        detailCount: Int?,
        detailState: ResetCreditDetailState
    ) {
        self.signature = signature
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
        self.sampleCount = sampleCount
        self.availableCount = availableCount
        self.detailCount = detailCount
        self.detailState = detailState
    }
}
```

- [ ] **Step 3: Add failing temporary-database tests**

Change the store initializer to accept an optional test-only path without changing production callers:

```swift
init(
    configuration: AppConfiguration,
    fileManager: FileManager = .default,
    userDefaults: UserDefaults = .standard,
    databaseURLOverride: URL? = nil
)
```

When the override is non-nil, use it as `databaseURL`; otherwise retain the existing Application Support path and permissions flow. Construct `QuotaHistoryStore` with a temporary database URL and an isolated `UserDefaults` suite, record the same complete bank twice, then a complete empty bank after expiry. Assert:

```swift
#expect(store.resetCreditHistory().count == 1)
#expect(store.resetCreditHistory()[0].sampleCount == 2)
#expect(store.resetCreditHistory()[0].lifecycle == .expired)
#expect(store.resetCreditBankRuns().count == 2)
#expect(store.resetCreditBankRuns()[0].sampleCount == 2)
store.clearAll()
#expect(store.resetCreditHistory().isEmpty)
#expect(store.resetCreditBankRuns().isEmpty)
```

Add a privacy assertion that no table column named `raw_id`, `description`, or `referral` exists.

- [ ] **Step 4: Add SQLite schema and indexes**

Create these tables during migration:

```sql
CREATE TABLE IF NOT EXISTS reset_credits (
  fingerprint TEXT PRIMARY KEY,
  reset_type TEXT NOT NULL,
  safe_title TEXT,
  granted_at REAL,
  grant_time_source TEXT NOT NULL,
  expires_at REAL,
  first_seen_at REAL NOT NULL,
  last_seen_at REAL NOT NULL,
  latest_status TEXT NOT NULL,
  lifecycle TEXT NOT NULL,
  sample_count INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS reset_credit_bank_runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  signature TEXT NOT NULL,
  first_observed_at REAL NOT NULL,
  last_observed_at REAL NOT NULL,
  sample_count INTEGER NOT NULL,
  available_count INTEGER NOT NULL,
  detail_count INTEGER,
  detail_state TEXT NOT NULL
);
```

Add indexes on `reset_credits(granted_at)`, `reset_credits(expires_at)`, and `reset_credit_bank_runs(last_observed_at)`.

- [ ] **Step 5: Implement upsert and run coalescing**

For each successful bank summary:

1. upsert each returned detail by fingerprint;
2. increment its sample count and update last seen/status without changing its original grant/expiry facts;
3. build the bank signature from available count, detail state, and sorted `fingerprint:status` pairs;
4. update the last run when its signature matches, otherwise insert a new run;
5. classify missing credits only when details are complete, never for count-only or capped responses.

The live parser never invents a grant time. The `.inferredExpiryMinus30Days` source is accepted only by explicit local import code after the applicable offer's 30-day rule has been confirmed; it cannot overwrite a `.provider` timestamp.

Use SQL parameter binding for every value. Do not interpolate fingerprints, titles, or timestamps into SQL strings.

- [ ] **Step 6: Add conservative likely-redemption confirmation**

`confirmLikelyResetCreditRedemption(at:)` may change one `disappearedUnknown` row to `likelyRedeemed` only when:

- two consecutive complete bank runs differ by exactly one available credit;
- exactly one previously available fingerprint disappeared before expiry;
- the weekly quality engine accepted a reset transition in the same refresh.

If any condition fails, leave the row unknown.

- [ ] **Step 7: Wire storage into accepted reads and clear-history**

Record bank facts from every successful `latestAttemptSnapshot`. Call redemption confirmation only after the weekly candidate is accepted. Extend `clearAll()` to delete `reset_credits` and `reset_credit_bank_runs` before `VACUUM`.

No reset-credit fields may be added to `ProductAnalyticsEvent`, `recordQuotaStateSample`, or upload payloads.

- [ ] **Step 8: Run persistence tests and commit**

Run:

```bash
swift test --filter ResetCreditHistoryTests
swift test --filter ResetCreditPersistenceTests
swift build --product QuotaCapsuleMac
```

Expected: PASS.

Commit:

```bash
git add Sources/QuotaCapsuleCore/ResetCreditHistory.swift Tests/QuotaCapsuleCoreTests/ResetCreditHistoryTests.swift Sources/QuotaCapsuleMac/QuotaHistoryStore.swift Sources/QuotaCapsuleMac/QuotaStore.swift Tests/QuotaCapsuleMacTests/ResetCreditPersistenceTests.swift
git commit -m "Keep local reset credit history"
```

---

### Task 3: Render every current credit at the bottom to the minute

**Files:**
- Modify: `Sources/QuotaCapsuleCore/QuotaLocale.swift`
- Modify: `Sources/QuotaCapsuleMac/QuotaStore.swift`
- Modify: `Sources/QuotaCapsuleMac/CapsuleViews.swift`
- Modify: `Tests/QuotaCapsuleCoreTests/WeeklyDisplayModelTests.swift`

**Interfaces:**
- Produces: `ResetCreditDisplayRow` and localized footer strings.
- Consumes: accepted `snapshot.resetCreditBank` only.

- [ ] **Step 1: Add failing minute-format and completeness tests**

Add:

```swift
@Test("reset credit rows use local time through minutes")
func resetCreditRowsUseMinutePrecision() throws {
    let timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
    let expiry = try Date.ISO8601FormatStyle().parse("2026-07-18T00:33:54Z")
    let copy = QuotaCopy(locale: .zhHans)

    #expect(copy.resetCreditRow(index: 1, expiresAt: expiry, timeZone: timeZone) == "重置券 1 · 7 月 18 日 08:33 到期")
    #expect(!copy.resetCreditRow(index: 1, expiresAt: expiry, timeZone: timeZone).contains("08:33:54"))
    #expect(copy.resetCreditRow(index: 2, expiresAt: nil, timeZone: timeZone) == "重置券 2 · 未提供到期时间")
}

@Test("capped details admit missing expiry rows")
func cappedBankCopyIsHonest() {
    let copy = QuotaCopy(locale: .zhHans)
    #expect(copy.resetCreditCount(available: 4) == "4 张重置券可用")
    #expect(copy.resetCreditDetailsMissing(missing: 2) == "另有 2 张未返回到期详情")
}
```

- [ ] **Step 2: Run the focused suite and verify failure**

Run `swift test --filter WeeklyDisplayModelTests`.

Expected: FAIL because reset-credit copy does not exist.

- [ ] **Step 3: Implement locale-aware footer rows**

Add `QuotaCopy` methods for Simplified Chinese, Traditional Chinese, and English. Date formatting must:

- use the passed time zone;
- use a fixed `en_US_POSIX` locale internally where needed for stable numerics;
- show month, day, hour, and minute;
- omit seconds;
- sort expiring rows ascending and non-expiring rows last.

- [ ] **Step 4: Add current-bank presentation values to `QuotaStore`**

Define:

```swift
struct ResetCreditDisplayRow: Identifiable, Equatable {
    let id: String
    let text: String
}
```

Expose `resetCreditCountText`, `resetCreditRows`, and optional `resetCreditMissingDetailsText`. Build visible rows only from credits whose status is `.available`; compute the missing-detail count as `max(0, availableCount - visibleRows.count)`. Use the fingerprint only as the SwiftUI identity; never render or log it.

For `resetCreditBank == nil` or count-only details, display only the authoritative count and an honest details-unavailable line. For an explicit complete zero bank, show `暂无可用重置券`.

- [ ] **Step 5: Add the bottom footer**

Create a `ResetCreditFooterView` inside `CapsuleViews.swift` and place it after the diagnostics disclosure as the final child of the expanded panel's main `VStack`.

The footer contains:

- section title and authoritative count;
- one visible row per returned current credit;
- one missing-detail line when the list is capped/count-only;
- no redemption button and no optimization recommendation.

- [ ] **Step 6: Run tests and compile**

Run:

```bash
swift test --filter WeeklyDisplayModelTests
swift build --product QuotaCapsuleMac
```

Expected: PASS.

Commit:

```bash
git add Sources/QuotaCapsuleCore/QuotaLocale.swift Sources/QuotaCapsuleMac/QuotaStore.swift Sources/QuotaCapsuleMac/CapsuleViews.swift Tests/QuotaCapsuleCoreTests/WeeklyDisplayModelTests.swift
git commit -m "Show reset credit expiry minutes"
```

---

### Task 4: Document privacy, backfill local history, and run combined acceptance

**Files:**
- Modify: `docs/product/forecast-methodology.md`
- Modify: `docs/product/acceptance-criteria.md`
- Modify: `docs/product/mvp-scope.md`
- Modify: `CHANGELOG.md`
- Local only: `local-state/audits/2026-07-14-reset-credit-backfill/`

**Interfaces:**
- Produces: public documentation and private installed-app evidence.

- [ ] **Step 1: Update public documentation**

Document:

- authoritative count versus nullable/capped details;
- minute-level normal display and second-level local storage;
- SHA-256 fingerprint privacy boundary;
- indefinite local retention and clear-history behavior;
- conservative expired/likely-redeemed/unknown classification;
- reset credits do not alter weekly risk color until a reset actually occurs;
- redemption and optimization are outside this release.

- [ ] **Step 2: Run all automated gates**

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

- [ ] **Step 3: Verify no sensitive values can leave the Mac**

Run:

```bash
rg -n "resetCredit|reset_credit|fingerprint|grantedAt|expiresAt" Sources packages scripts
rg -n "resetCredit|reset_credit|fingerprint|grantedAt|expiresAt" packages/analytics-collector Sources/QuotaCapsuleMac/QuotaHistoryStore.swift
```

Expected: persistence/parser/UI references are present; analytics payload construction contains no credit count, fingerprint, title, grant, expiry, or lifecycle property.

- [ ] **Step 4: Install exactly one Beta app and create local-only backfill evidence**

Run the repository install flow from the release checklist, then verify:

```bash
mdfind 'kMDItemFSName == "Quota Capsule*.app"c'
pgrep -fl 'Quota Capsule|QuotaCapsuleMac'
```

Expected: one `/Applications/Quota Capsule Beta.app` and one running process.

Create `local-state/audits/2026-07-14-reset-credit-backfill/` only after confirming it is ignored by Git. Store the sanitized current and previously observed `grantedAt`, `expiresAt`, reset type, and lifecycle without raw IDs. Insert the previously observed expired record in one SQLite transaction using bound parameters and a locally generated fingerprint over the namespaced value `local-backfill:<grant>:<expiry>`; immediately query the row back and verify every safe field. The exact personal timestamps stay in this ignored directory and database, never in a commit or command transcript intended for GitHub.

- [ ] **Step 5: Perform visual and data acceptance**

Verify in the installed app:

- every returned available credit appears once at the bottom;
- each expiry minute matches the same sanitized app-server response in Asia/Shanghai;
- the authoritative count is still correct when details are count-only or capped in fixtures;
- no credit text appears in the collapsed capsule or menu-bar title;
- the local history contains current credits plus the expired local backfill;
- `清除本地历史` removes quota and reset-credit history only after explicit confirmation.

- [ ] **Step 6: Commit documentation**

```bash
git add docs/product/forecast-methodology.md docs/product/acceptance-criteria.md docs/product/mvp-scope.md CHANGELOG.md
git commit -m "Document reset credit history"
```

- [ ] **Step 7: Run final release preparation**

Follow `docs/operations/release-checklist.md` for contributor audit, version `0.3.1`, tag `v0.3.1-beta.1`, signed package, installed-app smoke test, PR/CI, merge, tag, release, and post-release verification. Do not declare completion until the ten-second submenu recording and every reset-credit footer row are both verified against the installed bundle.
