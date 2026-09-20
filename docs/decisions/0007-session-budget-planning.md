# Decision 0007: Plan quota around available sessions

Status: Accepted for implementation
Date: 2026-09-20

## Purpose

Help users allocate their remaining weekly quota to the times they intend to use it. Observed consumption already reflects responses to earlier warnings, task availability, model choices, and account limits. It is not an estimate of unconstrained demand.

## Contract

- Revised 2026-09-20: default daily 09:00–23:00 with zero reserve is active immediately. Customization is optional. Weekly-used progress stays visible in the capsule. If a deadline precedes the next default session, allocate over the remaining time. This fallback does not override custom plans.
- The endpoint is the earlier of the natural weekly reset and an available reset credit's expiry. A credit remains a manual action; expiry alone does not replenish quota.
- Allocate spendable quota (live remaining minus an explicit user reserve) in proportion to scheduled hours and session weights before the endpoint.
- Freeze the current session allocation at the first fresh observation in that session. Deduct subsequent account consumption, including other devices. Do not increase the allowance simply because the user slows down after a warning.
- Start a new allocation at the next session, a confirmed reset, an endpoint change, or an explicit plan edit. Reopening the app preserves the anchor. A remaining-balance increase above the anchor requires replanning rather than inventing negative consumption.
- Outside a session, show the next planned use time. If no session remains, ask the user to change the plan; never divide by zero or imply automatic overnight work.
- Keep the five-hour limit visible as a separate immediate constraint. Weekly budget is not a guarantee that a task can complete within all account limits.
- Stale, missing, and unconfirmed reset data suspend budget advice. Persisted anchors are not live readings.
- Historical projections stay in a secondary disclosure and describe observed behavior. They do not determine the primary allowance or claim causal effects of warnings.

## Initial scope

A recurring local-time session with selectable weekdays, overnight support, an explicit reserve, and an editable weight for today's session. Users can model continuous background work with a full-day session. Settings and anchors are stored locally in UserDefaults; old quota history is preserved. No schedule or plan state is added to outbound analytics.

## Structure and validation

`UsageBudgetPlanner` is pure Swift domain logic; `UsageBudgetState` owns local persistence; `UsageBudgetViews` owns native presentation. The existing TypeScript desktop app remains a forecast preview, not a second installed production app, and must be labeled accordingly.

Tests cover allocation conservation, partial and overnight sessions, DST, reserves, session freeze/restart, cross-device consumption, endpoint changes, expired credits, stale reads, and missing windows. Render tests use synthetic readings only. Historical observational replay cannot identify the causal effect of recommendations; do not claim improved counterfactual accuracy or reduced waste before prospective evaluation.
