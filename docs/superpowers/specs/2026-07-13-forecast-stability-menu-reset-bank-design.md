# Forecast Stability, Menu Lifetime, and Reset Bank Design

**Target release:** `v0.3.1-beta.1`

**Status:** Conversational direction approved; written specification awaiting owner review

**Scope:** Public repository only; one installed Beta application; Weekly Only product mode

## 1. Executive decision

This patch release will fix three user-visible failures together because they share the same product contract: the application must give an immediate, understandable weekly-budget answer without displaying false precision or an unstable interface.

The release will:

1. stop rebuilding the status menu on one-second clock ticks, eliminating submenu flicker;
2. make activity evidence invariant to polling frequency and flat samples;
3. replace extreme-quantile fusion with a robust consensus forecast and explicit disagreement handling;
4. present observed usage in the period actually observed instead of leading with an extrapolated `%/day` rate;
5. display the exact local expiry time of available reset credits returned by Codex;
6. prove the result through shared fixtures, unit tests, repository audit, and a recording of the installed app.

This is a patch to the adaptive Weekly Only design, not a return to a five-hour-window product. The data model remains capable of accepting additional upstream windows later, but no five-hour information will be added to the current user interface.

## 2. Evidence and problem statement

### 2.1 Menu flicker

`QuotaStore.currentTime` publishes every second. `StatusBarController` currently observes the store's broad `objectWillChange` signal and rebuilds the whole `NSMenu`. Replacing a menu while AppKit is tracking it closes an open submenu; cursor hover then opens it again. A clock update therefore appears as a roughly one-second flash.

The clock is legitimate capsule data, but it is not a reason to replace menu objects.

### 2.2 Forecast range explosion

The current activity estimator treats each upward run as a separate measurement and adds rounding uncertainty to every run. Flat polls split those runs. More frequent polling therefore increases uncertainty even when the underlying usage history is identical.

In the observed case, 16 upward transitions within about 8.25 hours produced an activity band of approximately `5.7–91.9%/day`. Quantile fusion then selected that same source for both forecast extremes. After projection, the negative lower result was silently clamped to zero, yielding the apparently precise but unhelpful `预计剩余 0–43.9%`.

Three defects are combined here:

- measurement uncertainty depends on polling layout;
- one wide source can dominate both ends of a three-source range;
- presentation hides a negative projection by clamping it without explaining the possible early-exhaustion scenario.

### 2.3 Misleading pace language

`观察速度 48.2–66.6%/天` means “if the recently observed consumption continued for 24 hours, it would consume this many weekly-quota percentage points.” It is neither a probability nor a directly observed 24-hour result. When only about eight hours have been observed, leading with this normalized rate obscures the real evidence.

### 2.4 Reset-credit precision is available but hidden

The Codex app-server response includes `rateLimitResetCredits.credits[].expiresAt` as an exact timestamp. The application does not currently model or display it. Normal product copy should show local time to the minute; diagnostics may show seconds. Upstream identifiers and descriptive payloads are not needed and must not be persisted or logged.

## 3. Alternatives considered

### A. Minimal patch

Change the activity arithmetic and defer menu rebuilding, while leaving fusion and copy unchanged.

This is fast, but a future wide estimator could recreate the same misleading range, and `%/day` would remain difficult to interpret. It does not fully address the user failure.

### B. Measurement invariance plus robust presentation — selected

Fix activity measurement, use consensus-based fusion, expose disagreement, present actual observed usage, and add reset-credit expiry data. This preserves the existing architecture while correcting both the mathematics and the user contract.

### C. Full probabilistic/Bayesian forecast

Model latent consumption rate, polling quantization, change points, and user-session behavior probabilistically.

This may become valuable after the project has labelled histories and forecast-outcome backtests. At the current beta stage it would introduce difficult-to-validate assumptions and a new form of false precision. The selected design keeps estimator boundaries modular so a calibrated probabilistic model can replace fusion later.

## 4. Architecture and data flow

The existing separation remains:

```text
Codex app-server
  -> quota response parser
  -> provider-neutral snapshot
  -> history store
  -> weekly evidence estimators
  -> robust forecast
  -> display model
  -> capsule and status menu
```

Two additions are required:

- reset credits are parsed into optional provider-neutral snapshot data;
- status-menu rendering consumes an equatable presentation snapshot rather than the store's undifferentiated change stream.

The forecast core returns mathematical values and reason codes. It must not perform copy-oriented clamping. The display model decides how a positive, negative, or zero-crossing projection is explained.

## 5. Forecast contract

### 5.1 Input hygiene

All estimators use only the active weekly cycle and must reject or segment around:

- reset-boundary crossings;
- malformed or non-finite values;
- impossible timestamps;
- backward usage corrections large enough to invalidate a monotonic segment;
- samples from a different provider or quota identity.

Duplicate and flat samples remain useful for elapsed-time coverage but must not add percentage uncertainty.

### 5.2 Polling-invariant activity evidence

For each clean monotonic segment in the selected horizon:

1. use the first and last rounded observations as the cumulative measurement;
2. apply endpoint quantization uncertainty once to the segment, not once per upward transition;
3. divide that cumulative increase band by the segment's elapsed coverage;
4. combine multiple genuinely separated segments using elapsed-time/reliability weighting;
5. apply recency decay to segment evidence, not to individual polling artifacts.

Inserting flat polls, duplicating samples, or representing the same endpoint change as a staircase must not materially widen the result. A downward correction starts a new quality segment; it does not allow negative consumption to cancel prior use.

The estimator result exposes:

- actual coverage duration;
- observed cumulative increase band;
- optional normalized daily pace band;
- reliability and quality reasons.

### 5.3 Evidence sources

The release retains three independently computed sources when available:

- **cycle pace:** consumption across the active weekly cycle;
- **recent pace:** consumption across a bounded recent horizon;
- **activity pace:** recency-weighted clean activity segments.

Each source publishes a midpoint, within-source half-width, reliability, coverage, and reason codes. The UI must not imply that source names are independent observations when they overlap in time.

### 5.4 Robust fusion

Fusion will use a median/MAD consensus rather than taking the lower and upper weighted quartiles of source endpoints. With only three overlapping estimators, reliability is more defensible as a confidence input than as permission for one estimator to control both interval edges.

For three or more valid sources:

1. the fused center is the median of source midpoints;
2. within-source uncertainty is the median of source half-widths;
3. between-source disagreement is `1.4826 * median(abs(midpoint - fused center))`;
4. the final pace half-width is `max(within-source uncertainty, between-source disagreement)`;
5. the pace interval is clipped only to the physically meaningful lower bound of zero, never to a copy-friendly reset remainder.

For two valid sources, no robust majority exists. Fusion therefore returns the hull of both source intervals and uses their decision agreement only to determine whether confidence can rise above low. For one valid source, its interval is returned unchanged and confidence is low.

Source reliability and usable coverage decide whether a source is valid and determine confidence; they do not shift the three-source median. Confidence is downgraded when sources disagree on the product decision, even if transition count is high. Source values and exclusion reasons remain available in diagnostics.

The constant `1.4826` is the conventional normal-consistency scale for median absolute deviation, not a value fitted to the captured example. Backtests must cover calm, bursty, sparse, reset-adjacent, and corrected histories before this constant or the estimator set changes.

No single estimator can define both sides of a three-source final band. A one-source result is permitted only with an explicit low-confidence label.

### 5.5 Projection semantics

The mathematical projection at reset is:

```text
remaining now - pace per day * days to reset
```

The core returns the raw interval, including negative values. If pace is positive, the conditional exhaustion interval is derived as `remaining / pace`; it is also kept raw until formatting. Presentation follows these rules:

- **entire interval positive:** show `重置时预计剩 X–Y%`;
- **entire interval negative:** show that the quota may be exhausted before reset and show an exhaustion-time range when computable;
- **interval crosses zero:** explain the split scenario, for example `按较快节奏可能提前用完；较慢情景最多剩 Y%`;
- **insufficient or contradictory evidence:** show what is known now and why a reliable reset projection is not ready.

The UI must never turn a negative lower projection into a silent `0` endpoint. Display precision is whole percentage points by default; decimals are reserved for diagnostics. A wide interval must be described as uncertainty, not rendered as false precision.

### 5.6 Immediate value and budget guidance

There is no fixed six-hour calibration gate. From the first successful snapshot, the product always shows:

- current weekly use and time elapsed;
- exact next reset time;
- safe spend for the next 24 hours, computed from remaining allowance and time;
- the evidence currently available and its coverage.

The safe next-24-hour budget is:

```text
remaining * min(24 hours, time to reset) / time to reset
```

It is rounded down for display so the recommendation never overstates the time-balanced allowance.

When recent evidence exists, primary copy uses the observed period, for example:

```text
近 8 小时 15 分钟已用约 16–18%
```

Normalized `%/day` remains available in diagnostics with an explicit explanation. The main surface does not lead with it.

The next-24-hour budget remains an actionable constraint, not a forecast claim. Copy must distinguish `建议最多使用` from `预计会使用`.

### 5.7 Confidence and risk state

Confidence considers all of the following:

- usable elapsed coverage;
- observed cumulative change;
- number and quality of monotonic segments;
- agreement between estimator decisions;
- reset proximity and stale-data state.

Transition count alone cannot produce medium or high confidence. High confidence requires adequate coverage plus estimator agreement. Low confidence does not hide useful observations or budget guidance.

The user-facing risk state remains compact: early, sustainable, watch, or likely to run out. It is based on whether the robust pace band is below, around, or above the sustainable pace, with reason codes available in diagnostics.

## 6. Reset-credit model and interface

### 6.1 Data model

Add a provider-neutral value type containing only:

- status;
- reset type;
- granted timestamp when available;
- expiry timestamp;
- short display title when safe and useful.

The quota snapshot contains an optional credit collection:

- `nil` means the field was unavailable, unsupported, or not parsed;
- an empty collection means the provider explicitly reported no credits;
- a non-empty collection is sorted by expiry.

This distinction prevents a temporary schema or transport issue from being displayed as `0 张`.

### 6.2 Parsing and privacy

The parser validates timestamp ranges, skips malformed entries without failing the quota read, and accepts only relevant available credits for the main count. Raw credit IDs, referral metadata, and verbose upstream descriptions are not stored, logged, or included in fixtures.

Stale quota data may retain the last successful credit list only when the UI clearly labels the last successful update time.

### 6.3 Presentation

The expanded weekly view shows a compact summary only when credit state is known:

```text
3 张重置券可用，最早于 7 月 18 日 08:33 到期
```

Diagnostics list every available credit with its local expiry to the minute; seconds may be shown in the detailed row or copied diagnostic text. The collapsed capsule does not add credit information because weekly risk and pace remain the primary glanceable purpose.

This release is read-only. Redeeming a credit, choosing when to use it, or automating redemption is out of scope.

## 7. Menu lifetime and update scheduling

Introduce an equatable `StatusBarPresentation` (or equivalent) containing only fields that affect the status item and menu. `StatusBarController` observes deduplicated presentation changes instead of every store mutation.

Update rules:

- a one-second countdown tick may redraw the capsule but does not rebuild the menu;
- data, locale, display-mode, and relevant settings changes may request a menu update;
- while `NSMenu` is tracking, requested structural updates are queued;
- tracking end applies at most one latest pending update;
- submenu and highlighted-item identity remain stable during tracking.

The implementation should update existing menu-item values in place where practical. Full rebuild remains acceptable outside tracking for structural changes.

## 8. Test-driven implementation and acceptance

Production changes begin only after a failing test demonstrates each defect.

### 8.1 Shared forecast fixtures

Swift and TypeScript parity fixtures will cover:

- the same start/end usage with sparse polls, flat polls, duplicate polls, and a one-point staircase;
- the captured regression shape without personal timestamps or account data;
- bursty and calm weeks;
- downward correction and reset boundaries;
- one-source, two-source, and three-source disagreement;
- projections fully positive, fully negative, and crossing zero;
- stale and insufficient evidence.

Required invariants:

- inserted flat/duplicate polls do not widen activity uncertainty;
- equivalent histories produce equivalent risk decisions;
- raw negative projections remain negative in the model;
- no presentation path emits a silent clamped `0–Y%` range;
- Swift and TypeScript produce the same fixture classification and bounded numeric tolerances.

### 8.2 Reset-credit tests

Tests cover:

- exact timestamp decoding and local-time formatting;
- chronological sorting;
- missing field versus explicit empty list;
- malformed entry isolation;
- unavailable/expired filtering;
- absence of upstream IDs from the provider-neutral model and diagnostics;
- Chinese, English, and system-language presentation.

### 8.3 Menu tests

A pure update gate or presentation reducer must prove:

- repeated clock ticks cause zero menu rebuilds;
- an ordinary relevant change causes one update;
- multiple relevant changes during menu tracking are coalesced;
- tracking end applies one latest update;
- locale changes still refresh all menu text.

### 8.4 Installed-app acceptance

Before release, test the signed app installed in `/Applications`, not only the build product:

1. confirm exactly one installed Quota Capsule Beta application and one running instance;
2. keep the Language submenu open for at least ten seconds and record that it neither closes nor reopens;
3. verify collapsed and expanded views with live weekly data;
4. compare displayed reset-credit count and expiry minutes with the same app-server response without logging identifiers;
5. verify positive, negative, crossing-zero, low-confidence, stale, and no-credit fixture states;
6. inspect Chinese and English copy, light and dark appearance, and narrow-screen placement;
7. run the full test suite, release preflight, contributor check, and repository audit.

Release evidence records commands, outputs, installed bundle version, commit, tag, and acceptance media. A code diff or successful compilation alone is not completion evidence.

## 9. Documentation and release updates

The implementation pull request must update:

- forecast methodology and mathematical definitions;
- product acceptance criteria;
- troubleshooting and diagnostic explanations;
- README screenshots/copy when visible UI changes are final;
- changelog and version references;
- release checklist evidence for `v0.3.1-beta.1`.

The old run-summed activity-uncertainty description must be removed rather than left alongside the corrected method. No private paths, account payloads, credit IDs, or local-only audit media are committed.

## 10. Out of scope

- applying or scheduling reset credits;
- predicting whether a user will redeem a credit;
- reintroducing five-hour UI;
- adding unrelated provider windows to the primary screen;
- claiming statistical calibration before labelled outcome backtests exist;
- publishing a stable release before beta acceptance passes.

## 11. Definition of done

The release is done only when:

- all new regression tests fail before and pass after their production changes;
- polling-equivalent histories produce stable forecasts;
- the observed large-range failure is replaced by honest scenario language and bounded, explainable evidence;
- the Language submenu remains visually stable through live clock ticks;
- every available reset credit exposes a verified local expiry time to the minute;
- one installed Beta app matches the tested commit and version;
- contributor attribution contains only repository-authorized identities;
- public documentation matches shipped behavior;
- the pull request, CI, tag, release, and post-install smoke checks all pass.
