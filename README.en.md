# Quota Capsule

[简体中文](README.zh-CN.md) · [Project home](README.md) · [Releases](https://github.com/Bono12138/codex-quota-capsule/releases)

A local-first macOS quota companion for Codex. View weekly and five-hour limits, and allocate weekly quota to the hours you actually plan to work.

## Version status

The source development version is **0.5.0**. Check each [Release](https://github.com/Bono12138/codex-quota-capsule/releases) for its exact download contents. The older v0.3.6-beta.1 binary does not contain session budgeting.

## Planned session budgets

The capsule and expanded panel lead with two equal-width tracks. The time track combines wall-clock and scheduled usable-time progress, with distinct endpoint markers; the second track shows weekly quota used. Both clocks share the weekly window start and the earlier planning deadline. Outside scheduled hours, usable time pauses. The clocks can cross; scheduled time is not measured online activity.

The floating capsule defaults to 180×44 points; docked mode is 110×32 points. Hover for percentages and the exact deadline, or click to open details.

Short status messages vary by state and stay stable within each day. Five-hour limits remain a separate constraint, while budget details and history are expandable.

Budgeting starts automatically with a daily 09:00–23:00 schedule and zero reserve. Custom hours, weekdays and workload are optional. If the deadline falls before the next default session, the default uses the remaining time. Overnight and full-day schedules are supported.

With 60% remaining and three equal four-hour sessions before the deadline, each session initially gets 20%. Spending 5% leaves 15% for the current session. Slowing down does not increase its allocation. The next session redistributes the actual remaining balance.

The deadline is the earlier of the natural weekly reset and the earliest known available reset-credit expiry. This assumes you plan to redeem before expiry; expiration itself never restores quota. After redemption, fresh confirmed readings determine the next deadline.

Five-hour exhaustion takes priority over weekly budget status. Stale, failed, and unconfirmed data pause budget advice. Historical usage remains available under “Observed usage reference”: it may already reflect reactions to warnings and is not unconstrained demand.

## Install

Requires macOS 14+ and a signed-in ChatGPT/Codex desktop installation or compatible Codex CLI. Download the ZIP from [Releases](https://github.com/Bono12138/codex-quota-capsule/releases), move Quota Capsule Beta.app into Applications, and keep one installed copy.

A GitHub account is not required to download. This beta is ad-hoc signed and not notarized. Read [INSTALL.md](INSTALL.md) and the [first-time guide](docs/getting-started.en.md).

Check the last successful reading after launch. Versions supporting session budgets work immediately. Use “Customize hours (optional)” only when you want a different schedule. Language is available at the top menu level.

## Development

```bash
git clone https://github.com/Bono12138/codex-quota-capsule.git
cd codex-quota-capsule
npm ci
npm test
npm run build
npm run lint
npm run audit:repository
npm run audit:quota-surfaces
swift test
swift run QuotaCapsuleCoreSpec
npm run mac:install
```

- Sources/QuotaCapsuleCore: Swift quota domain, session planner, observed forecasts, source and history.
- Sources/QuotaCapsuleMac: production native app, UI and local budget persistence.
- Tests: Swift regression and synthetic rendering tests.
- packages/core and packages/source-codex: TypeScript forecast/source experiments.
- apps/desktop: browser forecast lab; session-budget parity is not implemented.
- packages/analytics-collector: optional consent-gated event collector.
- docs: product contract, methodology, acceptance and decisions.

The session planner, persistence and UI are separated into UsageBudgetPlanner, UsageBudgetState and UsageBudgetViews. Existing quota history is retained.

## Privacy and limits

Plans and session allocations stay local and are not included in outbound analytics. Existing product events require an explicitly configured endpoint and relevant consent. Never submit credentials, private paths, raw account responses or quota databases in issues.

Account snapshots reflect cumulative usage across devices, but cannot attribute timing within sampling gaps. One recurring session per selected weekday is supported at whole-hour precision, including overnight and full-day schedules. Multiple daily sessions, automatic habit learning, cross-device plan sync and causal evaluation of warnings are future work.

Budgets are allocations, not promises of task completion or predictions of unconstrained demand.

[Session mathematics](docs/product/session-budget-methodology.md) · [Documentation](docs/README.md) · [Acceptance](docs/product/acceptance-criteria.md) · [Changelog](CHANGELOG.md)

## Feedback and license

[Issues](https://github.com/Bono12138/codex-quota-capsule/issues) · Email: mmz1218bono@gmail.com · [X](https://x.com/starlightsz0) · Douyin: huotuichang439

MIT. See [LICENSE](LICENSE).
