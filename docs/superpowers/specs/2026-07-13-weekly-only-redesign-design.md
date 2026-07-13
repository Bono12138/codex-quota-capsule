# Quota Capsule Weekly Only Redesign

Date: 2026-07-13
Target release: `v0.2.0-beta.1`
Status: Product direction approved; written specification awaiting owner review

## 1. Decision

Quota Capsule will become a Weekly Only product.

The product will answer one question:

> At the user's recent pace, will the current Codex weekly allowance last until reset?

The 5-hour window is removed from the product model, prediction engine, user interface, copy, onboarding, analytics, history, tests, and public documentation. If the upstream source returns a short window, Quota Capsule ignores it. A future decision to support short windows would be a new product proposal, not a compatibility requirement for this release.

The redesigned product is a weekly runway and budget assistant, not a generic quota dashboard.

## 2. Evidence And Rationale

On 2026-07-12, Codex engineering lead Tibo Sottiaux announced that the 5-hour restriction was being temporarily removed for Plus, Business, and Pro plans:

- <https://x.com/thsottiaux/status/2076365965915467978>

OpenAI's current public pricing page still documents a shared 5-hour window with possible additional weekly limits:

- <https://chatgpt.com/codex/pricing/>

The long-term OpenAI policy is therefore unresolved. The product decision does not depend on that policy becoming permanent. Weekly allowance is the scarce budget that governs whether a user can continue working across days, so Quota Capsule will focus on that budget even if a short upstream limiter later returns.

A live local probe on 2026-07-13 returned only one 10,080-minute window, with `usedPercent=1`, `remainingPercent=99`, and no short window. The current app nevertheless returned a waiting-for-5-hours prediction. This proves that the existing primary flow no longer serves the current account state.

The existing local history also shows that raw percentage samples are not safe to feed directly into a linear forecast:

- 1,414 weekly samples were inspected.
- 1,296 samples were flat.
- 62 transitions increased and 55 decreased.
- 126 rows were classified as resets.
- Some periods alternated between 1% and 5% with different reset timestamps.

These anomalies require a data-quality layer before any pace calculation.

## 3. Goals

### 3.1 User goals

The user must be able to answer, at a glance:

1. Will this week's allowance last until reset?
2. Has recent usage become faster than the sustainable weekly pace?
3. How much can the user reasonably consume during the next 24 hours?
4. When is the weekly reset?
5. How confident is the product in its forecast when the data is incomplete or unstable?

### 3.2 Product goals

- Make weekly runway the only primary concept.
- Prefer an honest forecast range over false point precision.
- Keep the collapsed capsule glanceable.
- Put diagnostics and source details outside the normal decision surface.
- Never convert stale, conflicting, or insufficient data into a reassuring state.
- Keep all calculations local.
- Preserve the current native macOS visual language while improving contrast and information hierarchy.

### 3.3 Engineering goals

- Establish one explicit Weekly Only domain model.
- Separate raw ingestion, cleaned observations, pace estimation, forecast, and presentation.
- Make data-quality failures testable.
- Establish real Swift test coverage.
- Keep Swift and TypeScript behavior aligned through shared fixtures.

## 4. Non-Goals

- Supporting or displaying a 5-hour window.
- Supporting monthly, credit, API-billing, or team-admin limits.
- Predicting token counts or cost.
- Attributing quota consumption to individual prompts, tasks, models, or projects.
- Adding multi-account support.
- Adding user-configurable forecast thresholds in this release.
- Adding a large historical analytics dashboard.
- Adding new notifications in this release.
- Restyling the app into a different design system.

## 5. User Experience Principles

### 5.1 Decision before evidence

The first line says whether the week looks sustainable. Percentages explain the decision; they are not the product's headline.

### 5.2 Calm, not alarmist

Use these user-facing states:

- `够用` / `On track`
- `偏快` / `Running fast`
- `可能不够` / `May run out`
- `正在校准` / `Calibrating`
- `已用尽` / `Exhausted`
- `数据暂不可用` / `Data unavailable`

Do not use `安全`, `注意`, or `危险` for weekly pacing. Color supports the text but never carries meaning alone.

### 5.3 Uncertainty is visible only when useful

Normal medium- or high-confidence forecasts show a range in the explanatory sentence. Low-confidence data shows `正在校准` instead of a large confidence card. A compact footer may show `预测可信度：中/高`; source internals remain in diagnostics.

### 5.4 Minimal normal surface

The normal expanded panel contains one conclusion, one dual-progress comparison, two actionable budget values, one small trend visualization, and a compact freshness line. Source, endpoint, release channel, database size, and detailed errors live under `更多操作 -> 数据诊断`.

## 6. Weekly Only Domain Model

### 6.1 Source reading

```text
WeeklyQuotaReading
- provider
- sourceStatus
- fetchedAt
- windowMinutes
- usedPercent
- remainingPercent
- resetsAt
- errorMessage
```

The adapter selects only a weekly candidate:

- Prefer exactly 10,080 minutes.
- Accept a duration within 60 minutes of 10,080 to tolerate small upstream variation.
- Ignore every shorter window.
- Return an explicit source error if no valid weekly candidate exists.

Validation rules:

- `usedPercent` and `remainingPercent` are finite and within `[0, 100]`.
- Their sum is within 1.5 percentage points of 100.
- `resetsAt` is in the future and no more than eight days after `fetchedAt`.
- `fetchedAt` is not materially in the future relative to the local clock.

### 6.2 Clean observation

```text
WeeklyObservation
- fetchedAt
- canonicalResetAt
- usedInterval
- remainingInterval
- cycleID
- qualityFlags
```

Raw readings are immutable. Clean observations are derived and may be excluded from forecasting without deleting the raw evidence.

### 6.3 Forecast result

```text
WeeklyRunwayForecast
- state
- confidence
- usedPercent
- remainingPercent
- elapsedPercent
- daysUntilReset
- sustainableRatePerDay
- recentRateBandPerDay
- cycleRateBandPerDay
- last24HourUsageBand
- projectedRemainingBandAtReset
- estimatedEmptyAtRange
- next24HourBudget
- currentCycleTrend
- headline
- detail
- qualityExplanation
```

Presentation must not reach into raw source structures. It renders this forecast result.

## 7. Data Quality And Cycle State Machine

### 7.1 Freshness

- Fresh: latest successful reading is no more than 180 seconds old.
- Stale: a prior successful reading exists but is older than 180 seconds after a failed or missing refresh.
- Unavailable: no usable successful reading exists.

Stale readings freeze all usage and elapsed values at their fetch time. They never produce `够用`, `偏快`, or `可能不够`.

### 7.2 Reset clustering

Reset timestamps within five minutes belong to the same reset cluster. The canonical reset timestamp is the rolling median of accepted timestamps in that cluster. Second-level timestamp drift must never create a new cycle.

### 7.3 Confirming a new cycle

A reading becomes a candidate new cycle when both are true:

- Its reset cluster differs from the active cluster by more than five minutes.
- Usage drops by at least two percentage points or the reset moves forward by at least six hours.

The candidate becomes active only after three consecutive readings, spanning at least two minutes, agree with the new cluster. Until confirmation, the forecast state is `正在校准`.

This rule covers scheduled resets and manual OpenAI resets while rejecting one-off source oscillations.

### 7.4 Corrected readings inside one cycle

A negative usage delta inside the active reset cluster is not consumption and never enters a rate estimate.

- One or two lower readings are quarantined as anomalies.
- Three consecutive lower readings with a stable reset cluster rebase the displayed level.
- The rebase creates a quality flag and a new rate segment; no slope crosses the correction boundary.

### 7.5 Alternating or conflicting streams

If readings alternate between distinct usage levels or reset clusters during the last five refreshes, the stream is unstable. The app displays `正在校准` and retains the last accepted observation for reference, but emits no runway claim.

The stream returns to stable after three consecutive mutually consistent readings.

### 7.6 Sampling grain

The app may poll every 60 seconds, but forecasting operates on:

- percentage transition points;
- one representative observation per five-minute bucket;
- reset and correction events.

This prevents thousands of identical samples from dominating the calculation.

## 8. Quantization-Aware Pace Estimation

### 8.1 Percentage intervals

When the source reports an integer percentage `p`, treat it as an interval:

```text
[p, min(p + 1, 100))
```

Therefore, 0% means less than 1%, not zero consumption. A flat sequence narrows the possible pace but does not prove a zero pace.

When the source reports a fractional percentage, retain the fractional value and use half of the reported decimal precision as the interval width.

### 8.2 Robust slope band

For each forecast horizon:

1. Use accepted observations only.
2. Form observation pairs separated by at least 30 minutes.
3. Compute a lower and upper slope from the interval endpoints.
4. Remove pairwise slopes outside three median absolute deviations when enough pairs exist.
5. Use the median lower slope and median upper slope as the horizon's pace band.

All rates are non-negative and expressed in percentage points per day.

### 8.3 Forecast horizons

Two horizons are required:

- Cycle pace: accepted observations from the current cycle.
- Recent pace: accepted observations from the most recent 24 hours.

Recent pace requires at least six hours of coverage and at least one accepted upward percentage transition. If it is unavailable, the forecast remains `正在校准` until the cycle pace has medium confidence.

The combined pace band is:

```text
lower = min(cycle.lower, recent.lower)
upper = max(cycle.upper, recent.upper)
```

The intentionally conservative combined range expresses both the user's sustained pattern and recent acceleration.

### 8.4 Sustainable rate

Reserve five percentage points at reset:

```text
reserve = 5
daysRemaining = secondsUntilReset / 86,400
sustainableRate = max(0, remainingPercent - reserve) / daysRemaining
```

The reserve covers source quantization and avoids labelling a forecast that lands exactly at zero as comfortable.

### 8.5 Projected remaining band

```text
pessimisticRemaining = remainingPercent - upperRate * daysRemaining
optimisticRemaining = remainingPercent - lowerRate * daysRemaining
```

Clamp displayed values to `[0, 100]`, but preserve negative internal values for run-out decisions.

### 8.6 Estimated exhaustion range

When the relevant rate is greater than zero:

```text
earliestEmptyAt = now + remainingPercent / upperRate
latestEmptyAt = now + remainingPercent / lowerRate
```

If the lower rate is zero, there is no finite latest estimate. The UI must not invent one.

### 8.7 Next-24-hour budget

```text
next24HourBudget = min(remainingPercent, sustainableRate)
```

The displayed unit is percentage points for the next 24 hours, not a vague multiplier.

## 9. Confidence

Confidence is a property of the evidence, not of the state color.

### Low

Any of the following:

- less than six hours of stable coverage;
- no accepted upward transition;
- active candidate reset or correction;
- unstable alternating stream;
- only stale data.

Low confidence produces `正在校准` or `数据暂不可用`, never a runway judgment.

### Medium

- at least six hours of stable coverage;
- at least one accepted upward transition;
- no unresolved anomaly in the last six hours;
- a finite cycle pace band.

### High

- at least 24 hours of stable coverage;
- at least three accepted upward transitions;
- both cycle and recent pace bands are available;
- no unresolved anomaly in the last 24 hours.

## 10. State Rules

Rules are evaluated in this order:

1. `数据暂不可用`: no fresh usable weekly reading.
2. `已用尽`: fresh remaining percentage is zero.
3. `正在校准`: confidence is low or the stream is unstable.
4. `够用`: pessimistic remaining at reset is at least 5%.
5. `可能不够`: optimistic remaining is below 0%; both pace scenarios run out before reset.
6. `偏快`: all other medium- or high-confidence cases, including a forecast range that crosses zero or leaves less than 5% in the pessimistic case.

This ordering prevents a noisy recent burst from immediately producing an alarming state when the sustained cycle pace remains viable.

## 11. User Interface

### 11.1 Collapsed capsule

The standard-width capsule contains:

1. State and weekly usage: `够用 · 本周已用 28%`.
2. Forecast sentence: `照最近速度，刷新时预计剩 16%–23%`.
3. Two compact comparison bars:
   - `时间 42%`
   - `用量 28%`

The narrow-width capsule contains the state, weekly usage, and one forecast sentence. It may omit the bars but must not replace them with unrelated diagnostics.

Examples:

- `够用 · 已用 28%` — `预计刷新时剩 16%–23%`
- `偏快 · 已用 61%` — `最近速度高于可持续速度`
- `可能不够 · 已用 74%` — `预计周五晚间见底`
- `正在校准 · 已用 1%` — `再积累一些稳定读数`
- `数据暂不可用` — `正在显示 10:42 的最后读数`

### 11.2 Expanded panel

Render in this order:

1. Hero conclusion
   - state;
   - remaining percentage;
   - one forecast sentence.
2. Dual progress
   - weekly time elapsed;
   - weekly quota used.
3. Actionable budget pair
   - `最近 24 小时用了 X%`;
   - `未来 24 小时建议不超过 Y%`.
4. Current-cycle trend
   - accepted actual usage;
   - sustainable budget line;
   - forecast range;
   - reset marker.
5. Compact freshness line
   - last successful update;
   - confidence only when medium or high.
6. Actions
   - refresh;
   - feedback;
   - more.

The trend is a small explanatory visualization, not a separate analytics dashboard.

### 11.3 Diagnostics

Move the following to `更多操作 -> 数据诊断`:

- source name;
- app-server method;
- source status and last error;
- latest raw and accepted timestamps;
- release channel and app version;
- local history size;
- quality flags.

Diagnostics must never expose credentials, prompts, session content, project names, or private paths.

### 11.4 Visual and accessibility requirements

- Preserve the existing capsule geometry, materials, corner radii, and general mint/neutral language.
- Increase secondary-text contrast against translucent surfaces.
- Avoid essential text below 11 pt.
- Always pair color with text and, where helpful, a system icon.
- Do not use a red alarm treatment for `偏快`; reserve stronger danger treatment for `可能不够` and `已用尽`.
- Keep controls keyboard accessible and preserve current menu-bar access.

## 12. Copy Rules

User-facing copy must:

- use `周额度`, `本周`, `周刷新`, or `未来 24 小时`;
- identify the forecast basis, such as `最近 24 小时` or `本周平均`;
- say `预计` and show a range when uncertainty is material;
- explain calibration without calling the source broken;
- freeze stale timestamps explicitly.

User-facing copy must not contain:

- `5 小时`;
- `5h`;
- `短窗口`;
- `当前速度 0.08x`-style multipliers;
- claims that 0% proves no usage;
- source or JSON-RPC terminology outside diagnostics.

## 13. Persistence And Migration

Increase the local history schema version.

Migration behavior:

- Delete local `5h` window rows.
- Keep raw weekly captures that remain structurally valid.
- Mark pre-migration derived weekly rates, reset flags, and projections as legacy and do not reuse them.
- Rebuild clean weekly observations from valid raw weekly samples when possible.
- If historical oscillation prevents a reliable rebuild, start the new forecast in `正在校准` without deleting valid raw weekly evidence.
- Remove short-window analytics properties and replace them with weekly forecast-quality properties.

The migration must be idempotent and tested against a copy of the current schema.

## 14. Architecture Boundaries

### Source adapter

Responsibilities:

- read app-server rate limits;
- select and validate one weekly reading;
- return source status.

It does not predict or interpret user risk.

### History and quality engine

Responsibilities:

- persist raw weekly readings;
- normalize reset clusters;
- confirm cycles and corrections;
- produce accepted observations and quality state.

It does not render copy.

### Forecast engine

Responsibilities:

- estimate quantization-aware pace bands;
- calculate sustainable pace, projected remaining range, and exhaustion range;
- assign confidence and product state.

It consumes accepted observations, never raw database rows.

### Presentation model

Responsibilities:

- convert forecast values into locale-aware copy and display metrics;
- provide one consistent model to the desktop capsule, menu bar, and web mock.

It does not recalculate forecast math.

### UI

Responsibilities:

- render collapsed, expanded, diagnostic, stale, exhausted, and calibration states;
- preserve interaction and accessibility behavior.

## 15. Swift And TypeScript Consistency

The native Swift app remains the release-critical implementation. TypeScript remains useful for provider-neutral packages and the browser mock.

Both implementations must consume shared, language-neutral JSON fixtures containing:

- source readings;
- accepted observations;
- expected quality state;
- expected forecast bands;
- expected product state.

Exact localized sentences may be tested per runtime, but mathematical outputs and state must match.

## 16. Testing Strategy

### 16.1 Swift test infrastructure

Add a real XCTest target. `swift test` must discover and run tests; the executable spec is no longer sufficient as the only Swift verification surface.

### 16.2 Unit scenarios

Required scenarios:

- valid weekly-only reading;
- upstream payload with both weekly and short windows, where short is ignored;
- missing weekly window;
- invalid percentages or reset time;
- integer 0% and flat plateaus;
- fractional readings;
- reset timestamp jitter within five minutes;
- confirmed scheduled reset;
- confirmed manual reset;
- one-off negative correction;
- accepted lower correction after three stable reads;
- alternating 1% and 5% streams;
- stale last-success data;
- exhausted weekly allowance;
- insufficient history;
- recent acceleration;
- recent slowdown;
- cycle and recent forecasts disagreeing;
- finite and non-finite empty-time bounds.

### 16.3 Invariants

- No NaN or infinite displayed value.
- No negative displayed percentage.
- Higher accepted usage with all other inputs equal cannot improve the forecast.
- Less remaining time with all other inputs equal cannot increase the sustainable daily budget.
- Stale or unstable data cannot produce a runway state.
- Reset jitter cannot create a new cycle.
- A short upstream window cannot change any Weekly Only result.

### 16.4 Historical replay

Create sanitized fixtures from the observed local anomaly shapes, without credentials or private content:

- long flat sequences;
- 1%/5% alternation;
- second-level reset jitter;
- manual reset to a lower percentage and later reset date.

Replay tests must prove that the new engine calibrates or quarantines these sequences instead of emitting extreme rates.

### 16.5 UI verification

Verify the installed Dev Local app with live and deterministic mock states:

- collapsed standard and narrow widths;
- expanded on-track, fast, may-run-out, calibrating, stale, unavailable, and exhausted states;
- light and dark desktop backgrounds;
- keyboard access and menu-bar consistency;
- no clipped copy or inaccessible low-contrast secondary text.

The Beta app is built only after Dev Local passes.

## 17. Acceptance Criteria

The release is acceptable only when:

1. A fresh weekly-only source produces a Weekly Only state, never a waiting-for-short-window state.
2. No public UI, onboarding, README, current-release documentation, analytics field, or product test treats 5 hours as a product concept.
3. Short upstream windows are ignored.
4. Flat integer readings do not produce an exact zero pace claim.
5. Alternating or decreasing readings produce calibration or correction handling, not extreme forecasts.
6. Reset timestamps may drift by seconds without starting a new cycle.
7. Stale and failed reads freeze the last data and suppress runway claims.
8. Swift and TypeScript shared fixtures agree on mathematical outputs and state.
9. `npm test`, lint, build, `swift test`, macOS specs, app builds, signing checks, and public staging audit pass.
10. The installed `/Applications/Quota Capsule Beta.app` visibly matches the tested Beta build and shows the Weekly Only design.

Forecast accuracy is evaluated after two clean weekly cycles are collected. The initial quality target is that the forecast interval covers at least 80% of later accepted observations at matching horizons. A formal point-error target is not a release gate until a trustworthy baseline exists.

## 18. Release Plan

This redesign is a minor-version beta release: `v0.2.0-beta.1`.

Release order:

1. Implement and test in the private working branch.
2. Build and visually verify `Quota Capsule Dev Local.app`.
3. Run historical replay and deterministic UI states.
4. Build and verify `Quota Capsule Beta.app`.
5. Run the full release candidate gate.
6. Run `npm run public:prepare`.
7. Review `PUBLIC_STAGING_AUDIT.md` for private or stale content.
8. Sync the reviewed public staging output.
9. Test the public sync tree independently.
10. Commit and push public `main`.
11. Confirm GitHub Actions.
12. Create the `v0.2.0-beta.1` tag and public beta release notes.
13. Confirm installation and launch from `/Applications` one final time.

The release notes must explain that Quota Capsule is now a Weekly Only runway assistant and that 5-hour limits are intentionally outside product scope.

## 19. Success Measures And Guardrails

Primary product success measures after release:

- The app can produce a trustworthy weekly runway judgment for stable weekly-only data.
- Users can understand the state without opening diagnostics.
- Forecast state changes are driven by accepted quota evidence, not polling noise.

Operational guardrails:

- Zero stale-as-current judgments.
- Zero unstable-data runway judgments.
- Zero short-window influence on Weekly Only state.
- No credentials or private monitor content in local analytics, fixtures, staging, or public release artifacts.

## 20. Deferred Decisions

The following are explicitly deferred and do not block `v0.2.0-beta.1`:

- whether to support a future monthly or credit-based allowance;
- whether to provide model-level consumption attribution;
- whether to let users choose a reserve other than 5%;
- whether to add proactive notifications;
- whether to restore any short-window feature if OpenAI brings it back.
