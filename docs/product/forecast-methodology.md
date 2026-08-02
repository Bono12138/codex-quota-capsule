# Adaptive Weekly Forecast Methodology

Status: current product contract
Updated: 2026-07-26
Applies to: current source candidate and later releases until superseded

## Product question

Quota Capsule does not try to make a raw percentage look more precise than it is. It answers:

> Before the next unavoidable quota refresh, is the remaining allowance likely to run out or be wasted, and what should the next-24-hour budget be?

The first valid reading must already provide value. It produces a wide early estimate from current-cycle evidence; there is no fixed waiting-time gate. More observations improve the estimate only when they add useful evidence.

The next burn horizon, the natural weekly reset, and the local data-read time are separate concepts. Quota reset time and data read time must remain separately labelled, and the interface must name which event currently defines the horizon.

## Current burn horizon

The forecast always chooses one concrete endpoint:

```text
burn horizon = min(natural weekly reset, earliest known available reset-credit expiry)
```

Only a reset credit of type `codexRateLimits` whose status is `available`, whose expiry is known, and whose expiry is strictly after the current time is eligible. Redeemed, redeeming, expired, unknown-type, undated, and count-only credits never invent a deadline. If the provider returns no usable credit detail, the natural weekly reset remains the fallback.

This is an explicit product assumption: a user with an available full reset credit will use the earliest-expiring credit before it expires. Its expiry therefore becomes the next planned quota refresh whenever it precedes the natural reset. After a redemption or natural reset, the app reads the new authoritative weekly reset and the remaining credit bank, then applies the same minimum rule again. The app does not predict a future reset timestamp before the upstream source confirms it.

The weekly cycle start remains `natural reset - weekly duration`; a credit does not rewrite historical pace evidence. Time progress uses that real cycle start and the selected burn horizon as its endpoint. This preserves the true amount of quota already consumed while making the remaining-time budget answer the event the user will actually act on.

## Input quality

A reading enters the forecast only when:

- the window duration is weekly, within source tolerance;
- used and remaining percentages are finite, bounded, and complementary;
- the reset is in the future and consistent with the read timestamp;
- the source is live rather than stale or failed;
- reset changes and downward corrections have passed the quality engine's confirmation rules.

A reset candidate needs three mutually consistent live readings spanning at least two minutes. A reset moving forward by at least six hours or accompanied by a usage drop of at least two percentage points starts a new cycle after confirmation. A persistent reset-time correction outside the five-minute cluster but without either new-cycle signal is confirmed on the same schedule, then rebases the current cycle instead of remaining in calibration forever. A downward correction starts a new clean segment and never becomes negative consumption. Alternating or stale streams cannot produce fresh reassurance.

An unused window has one narrower exception. While every accepted reading in the active cycle still reports 0%, some Codex versions return a provisional reset timestamp that advances or is recomputed after sleep, restart, or a long polling gap. Because that zero-only history contains no consumption evidence to preserve, a valid non-backward provisional reset replaces the earlier zero-only anchor even when the reset shift does not match the observation gap. This rule stops applying immediately when positive usage appears: the last provisional timestamp becomes the normal cycle anchor, and later reset changes require the full confirmation rules. It cannot reinterpret a positive reading or a usage drop as harmless drift.

## Quantized measurement model

The upstream percentage is displayed at limited precision. An integer reading `p` is modeled as the interval:

```text
[max(0, p - 0.5), min(100, p + 0.5)]
```

In other words, the measurement uncertainty is ±0.5 percentage point, clipped to `[0, 100]`. Pace and projection calculations propagate the lower and upper bounds. A displayed `0%` therefore does not prove that the true pace is exactly zero.

## Independent pace evidence

Each estimator returns a daily pace band, reliability in `[0, 1]`, real transition count, and coverage hours.

### Cycle evidence

Cycle evidence is available from the first valid reading. The cycle start is `reset time - weekly duration`; the used-percentage interval is divided by elapsed cycle days. Its reliability begins low and rises gradually with cycle coverage, capped so it cannot dominate richer live evidence.

### Recent evidence

Recent evidence uses cleaned observations from the latest 24 hours. It requires at least one real upward transition but never requires a fixed number of elapsed hours. Consecutive equal readings are reduced to the first observation of each reported level plus the latest trailing observation. Pairwise slopes separated by at least 30 minutes are calculated only across genuine increases, with quantized bounds; median and median-absolute-deviation filtering limit outlier influence. Repeated flat polling therefore adds elapsed idle time but cannot gain statistical weight merely because the app polled more often.

### Activity evidence

Activity evidence uses at most the latest 72 hours of the current clean segment. Each monotonic segment contributes one endpoint measurement interval, regardless of how often the same flat percentage was polled inside that segment. A downward correction closes the segment and begins a new one. The estimator then classifies observed intervals:

- an upward transition within three hours is an active-burst interval;
- an upward transition observed over three to twelve hours is ordinary use;
- flat intervals are idle; a transition observed across more than twelve hours assigns at most three hours to ordinary use and the remainder to idle.

The estimator calculates active consumption rate, a duty ratio of `active + ordinary` over total observed time, and an exponential decay from the most recent real transition with a 48-hour time constant. The reported activity pace is `active rate × duty ratio × recency decay`. It therefore preserves observed average consumption while falling during an idle period instead of leaving a burst rate frozen forever. Downward corrections contribute zero consumption, and activity evidence cannot by itself override cycle-wide evidence.

### Historical prior

Historical prior evidence is optional and deliberately weak. A completed cycle must contain at least 48 hours of clean coverage and two real transitions. The most complete clean segment in each completed cycle contributes a robust band; current-cycle evidence always has more influence. A short fragment never becomes a prior.

## Robust fusion and disagreement

The fusion rule depends on how many independent estimators are available:

- one source is preserved unchanged and remains low confidence;
- two sources use the full hull of both pace bands;
- three or more sources use the median midpoint and the widest of the median source half-width or `1.4826 × MAD(midpoints)`.

This median/MAD consensus prevents one burst from dominating while still widening when the independent estimators materially disagree. Confidence is low whenever evidence sources cross the sustainable-survival decision boundary. High confidence additionally requires at least 24 hours of clean coverage, three real transitions, at least three agreeing sources, and a narrow relative spread.

## Budget and projection math

Let:

- `R` = remaining percentage;
- `H` = hours to the selected burn horizon;
- `P = [P_low, P_high]` = fused percentage-points-per-hour pace band.

Then:

```text
sustainable hourly pace = remaining / hours to burn horizon
next-24-hour budget = (remaining / hours to burn horizon) * min(24, hours to burn horizon)
projected remaining at refresh = R - P * H
```

The projected interval is kept raw, including negative values. A range such as `[-20%, 44%]` means the faster evidence may exhaust the allowance before reset while the slower evidence may leave up to 44%; it must not be clamped into the misleading display `0%–44%`.

The product rounds the next-24-hour budget down for display. When the selected horizon is less than 24 hours away, the budget can legitimately equal the entire remaining allowance. It does not subtract an arbitrary hidden buffer; uncertainty is represented by the forecast interval and confidence explanation. The main surface describes the directly observed period and percentage change, for example “近 8 小时已用约 16%–18%”. A normalized `%/day` comparison is a diagnostic explanation only and never the primary user value.

## Outcome states

- `earlyEstimate`: only sparse current-cycle evidence is available; a preliminary range and low-confidence reason are shown immediately.
- `enough`: the conservative fused projected-remaining bound stays above zero.
- `watch`: the fused projection overlaps zero, so different supported pace scenarios lead to different survival outcomes. The user-facing label is `波动较大 / Uncertain pace`, not a definitive claim that usage is fast.
- `mayRunOut`: even the optimistic fused projection is below zero and no reliable evidence supports lasting to reset.
- `exhausted`: remaining allowance is effectively zero.
- `unavailable`: the source, timestamps, reset, or quality evidence cannot support an honest current estimate.

A single recent or activity estimator cannot directly promote the state to `watch`. It may widen the fused range or lower confidence, but only the final fused projection determines whether the allowance plausibly crosses zero.

When an earlier reset-credit expiry defines the horizon and the projection still leaves non-negative quota, the presentation adds the contextual action state `抓紧使用 / Use before reset`. It changes “本周时间” to “刷新进度”, names the credit-based horizon, and encourages using the remaining allowance before refresh. It must not override `watch`, `mayRunOut`, or an early projection that already indicates the allowance may run out first.

The calibrating state is a short, visible data-quality transition rather than a user waiting room. A first valid weekly window normally falls back to cycle evidence immediately. When a later reset or correction candidate is still unconfirmed, the UI keeps the last accepted percentages, labels them as accepted rather than newly updated, and pauses the pace judgment until confirmation.

A first accepted 0% reading is the exception to cycle-rate projection: quantization still preserves the possible [0, 0.5] measurement interval internally, but the UI says that no consumption has been observed and shows the next-24-hour budget without converting a few minutes of uncertainty into a pace warning. During candidate confirmation, the predictor creates a neutral calibrating presentation from the last accepted observation; it never computes a pace or risk verdict from the candidate.

For activity evidence, uncertainty is propagated through the first and last endpoints of each clean monotonic segment. If the source reports 5% → 9%, the actual increase interval is [8.5 - 5.5, 9.5 - 4.5] = [3, 5], not [3.5, 4.5]. A continuous 5% → 6% → 7% run uses the shared middle reading only once and therefore becomes [1, 3], not the contradictory sum [0, 2] + [0, 2]. Polling 5%, 5%, 5%, 9% produces the same band as polling only 5%, 9%; flat polls do not repeatedly spend the ±0.5-point endpoint uncertainty. Separate correction-delimited segments are accumulated conservatively.

## Confidence

- Low confidence: cycle-only evidence, no real current-cycle transition, a single source, or evidence sources disagree across a decision boundary.
- Medium confidence: at least two agreeing estimators, one real transition, at least three hours of clean coverage, and usable reliability.
- High confidence: at least three agreeing estimators, at least three spread transitions, at least 24 hours of clean coverage, fresh data, and narrow relative spread.

The UI explains the reason in words, such as cycle-only evidence, observed transition count, or multi-source agreement. Color is never the only confidence or risk signal.

## Stale and failed reads

When the latest data is stale or a refresh fails, the app may keep the last successful percentages for continuity, but it suppresses current pace and budget reassurance. It shows the last successful data read time, the next automatic read countdown, and the latest failure in diagnostics.

The stale surface also hides the pace-comparison sentence and forecast trend band; old percentages remain visibly labelled as the last successful reading rather than current guidance.

## Reset-credit facts and forecast interaction

`rateLimitResetCredits.availableCount` is the authoritative current count. Per-credit details may be absent or capped, so the interface distinguishes a count-only response from a complete empty bank and explicitly states how many expiry details were not returned.

Normal UI shows each returned available credit's expiry in the Mac's local time through the minute. The local database retains provider timestamps at second precision. Opaque upstream IDs are SHA-256 hashed immediately; raw IDs, descriptions, and referral payloads are neither modeled nor stored. Reset-credit history remains on this Mac until the user clears local history.

A reset credit that disappears after its expiry is classified as expired. A pre-expiry reset-credit disappearance remains unknown unless one complete bank transition and an accepted weekly reset in the same refresh support the conservative label likely redeemed. These are local classifications, not provider facts.

An available full reset credit with a known earlier expiry changes the burn horizon, time progress, sustainable pace, next-24-hour budget, projection endpoint, footer timestamp, and action copy. It does not change the measured weekly usage or fabricate a future weekly reset. No credit is automatically redeemed.

This release implements the deterministic “use the earliest-expiring credit before it expires” policy requested by the product owner. It does not solve a general demand-weighted redemption optimization problem. Alternative policies, uncertain future workloads, and multi-credit dynamic programming remain research topics governed by `docs/research/reset-credit-timing-optimization.md`.

## Cross-runtime parity and change control

Swift is the native macOS runtime and TypeScript supports the reference/demo runtime. Both consume `fixtures/weekly-runway-cases.json` and `fixtures/weekly-pace-equivalence.json`. They must agree on quality state, forecast state, polling-invariant pace evidence, provisional unused-window anchoring across application gaps, persistent reset-time correction recovery, budget rules, and edge cases.

Every algorithm change must include, in the same pull request:

1. a failing Swift test and a failing TypeScript test or shared fixture;
2. the implementation in both runtimes;
3. an update to this methodology if the product contract changes;
4. a changelog entry;
5. automated verification plus a real installed-app check before release.

## Known limits

- Upstream quota percentages are coarse and may change source behavior without notice.
- A first-reading estimate can be wide and should never be presented as certainty.
- Historical behavior may not predict a new work pattern; its reliability is capped.
- The product estimates allowance pace, not task complexity, tokens, monetary cost, or provider policy.
- User-visible wording must distinguish a weekly allowance reset from a local data refresh.
- Count-only credit responses cannot safely shorten the horizon because they contain no expiry timestamp.
- Pace history stored on one Mac is incomplete when the same account is used elsewhere. Current upstream percentage changes still include cross-device consumption between reads, but activity attribution and local coverage do not.
