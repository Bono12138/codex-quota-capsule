# Adaptive Weekly Forecast Methodology

Status: current product contract
Updated: 2026-07-13
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

Recent evidence uses cleaned observations from the latest 24 hours. It requires at least one real upward transition but never requires a fixed number of elapsed hours. Pairwise slopes separated by at least 30 minutes are calculated with quantized bounds; median and median-absolute-deviation filtering limit outlier influence. Repeated flat polling adds elapsed idle time but does not inflate transition count.

### Activity evidence

Activity evidence measures actual upward transitions from the baseline preceding the first recent burst through the current time. An idle period therefore lowers the average naturally instead of leaving a burst rate frozen forever. Downward corrections contribute zero consumption.

### Historical prior

Historical prior evidence is optional and deliberately weak. A completed cycle must contain at least 48 hours of clean coverage and two real transitions. The most complete clean segment in each completed cycle contributes a robust band; current-cycle evidence always has more influence. A short fragment never becomes a prior.

## Robust fusion and disagreement

Evidence is ordered by pace and fused with reliability-weighted quantiles:

- the lower forecast bound uses the weighted 25th percentile;
- the upper forecast bound uses the weighted 75th percentile.

This preserves meaningful disagreement between cycle, recent, activity, and historical estimates. One burst cannot dominate, but a slow recent pace also cannot erase heavy cycle-wide use. Confidence remains lower when estimators disagree.

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

The product rounds the next-24-hour budget down for display. It does not subtract an arbitrary hidden buffer; uncertainty is represented by the forecast interval and confidence explanation.

## Outcome states

- `earlyEstimate`: only sparse current-cycle evidence is available; a preliminary range and low-confidence reason are shown immediately.
- `enough`: the conservative projected-remaining bound stays above zero and reliable evidence is not materially above the sustainable pace.
- `watch`: the projection overlaps zero, reliable pace evidence is materially faster than sustainable, or estimators disagree across the survival boundary.
- `mayRunOut`: even the optimistic fused projection is below zero and no reliable evidence supports lasting to reset.
- `exhausted`: remaining allowance is effectively zero.
- `unavailable`: the source, timestamps, reset, or quality evidence cannot support an honest current estimate.

`calibrating` remains an internal data-quality transition, not a user waiting room. A valid live weekly window normally falls back to cycle evidence instead of withholding all value.

## Confidence

- Low confidence: cycle-only evidence or no real current-cycle transition.
- Medium confidence: at least one real transition and multiple usable estimators.
- High confidence: at least three spread transitions, at least 24 hours of clean coverage, fresh data, and agreement between estimators.

The UI explains the reason in words, such as cycle-only evidence, observed transition count, or multi-source agreement. Color is never the only confidence or risk signal.

## Stale and failed reads

When the latest data is stale or a refresh fails, the app may keep the last successful percentages for continuity, but it suppresses current pace and budget reassurance. It shows the last successful data read time, the next automatic read countdown, and the latest failure in diagnostics.

## Cross-runtime parity and change control

Swift is the native macOS runtime and TypeScript supports the reference/demo runtime. Both consume `fixtures/weekly-runway-cases.json` and must agree on quality state, forecast state, evidence behavior, budget rules, and edge cases.

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
