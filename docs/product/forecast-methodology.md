# Adaptive Weekly Forecast Methodology

Status: current product contract
Updated: 2026-07-14
Applies to: `v0.3.0-beta.1` and later until superseded

## Product question

Quota Capsule does not try to make a raw percentage look more precise than it is. It answers:

> At the pace supported by the evidence available now, is the remaining weekly allowance likely to last until reset, and what is a sustainable next-24-hour budget?

The first valid reading must already provide value. It produces a wide early estimate from current-cycle evidence; there is no fixed waiting-time gate. More observations improve the estimate only when they add useful evidence.

Quota reset time and data read time are separate concepts and must always be labelled separately in the interface.

## Input quality

A reading enters the forecast only when:

- the window duration is weekly, within source tolerance;
- used and remaining percentages are finite, bounded, and complementary;
- the reset is in the future and consistent with the read timestamp;
- the source is live rather than stale or failed;
- reset changes and downward corrections have passed the quality engine's confirmation rules.

A reset candidate needs three mutually consistent live readings spanning at least two minutes. A downward correction starts a new clean segment and never becomes negative consumption. Alternating or stale streams cannot produce fresh reassurance.

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

Recent evidence uses cleaned observations from the latest 24 hours. It requires at least one real upward transition but never requires a fixed number of elapsed hours. Pairwise slopes separated by at least 30 minutes are calculated with quantized bounds; median and median-absolute-deviation filtering limit outlier influence. Repeated flat polling adds elapsed idle time but does not inflate transition count or measurement uncertainty.

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
- `H` = hours to reset;
- `P = [P_low, P_high]` = fused percentage-points-per-hour pace band.

Then:

```text
sustainable hourly pace = remaining / hours to reset
next-24-hour budget = (remaining / hours to reset) * min(24, hours to reset)
projected remaining at reset = R - P * H
```

The projected interval is kept raw, including negative values. A range such as `[-20%, 44%]` means the faster evidence may exhaust the allowance before reset while the slower evidence may leave up to 44%; it must not be clamped into the misleading display `0%–44%`.

The product rounds the next-24-hour budget down for display. It does not subtract an arbitrary hidden buffer; uncertainty is represented by the forecast interval and confidence explanation. The main surface describes the directly observed period and percentage change, for example “近 8 小时已用约 16%–18%”. A normalized `%/day` comparison is a diagnostic explanation only and never the primary user value.

## Outcome states

- `earlyEstimate`: only sparse current-cycle evidence is available; a preliminary range and low-confidence reason are shown immediately.
- `enough`: the conservative projected-remaining bound stays above zero and reliable evidence is not materially above the sustainable pace.
- `watch`: the projection overlaps zero, reliable pace evidence is materially faster than sustainable, or estimators disagree across the survival boundary.
- `mayRunOut`: even the optimistic fused projection is below zero and no reliable evidence supports lasting to reset.
- `exhausted`: remaining allowance is effectively zero.
- `unavailable`: the source, timestamps, reset, or quality evidence cannot support an honest current estimate.

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

## Reset-credit facts are separate from the forecast

`rateLimitResetCredits.availableCount` is the authoritative current count. Per-credit details may be absent or capped, so the interface distinguishes a count-only response from a complete empty bank and explicitly states how many expiry details were not returned.

Normal UI shows each returned available credit's expiry in the Mac's local time through the minute. The local database retains provider timestamps at second precision. Opaque upstream IDs are SHA-256 hashed immediately; raw IDs, descriptions, and referral payloads are neither modeled nor stored. Reset-credit history remains on this Mac until the user clears local history.

A reset credit that disappears after its expiry is classified as expired. A pre-expiry reset-credit disappearance remains unknown unless one complete bank transition and an accepted weekly reset in the same refresh support the conservative label likely redeemed. These are local classifications, not provider facts.

Available credits do not change the weekly risk state, color, pace, or budget before an actual reset is confirmed. Redemption controls and optimal-use recommendations are outside this release and are governed separately by `docs/research/reset-credit-timing-optimization.md`.

## Cross-runtime parity and change control

Swift is the native macOS runtime and TypeScript supports the reference/demo runtime. Both consume `fixtures/weekly-runway-cases.json` and `fixtures/weekly-pace-equivalence.json`. They must agree on quality state, forecast state, polling-invariant pace evidence, budget rules, and edge cases.

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
