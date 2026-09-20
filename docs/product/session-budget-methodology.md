# Planned-session budget methodology

Status: implemented in the native 0.5.0 development source; distribution follows the release checklist.
Updated: 2026-09-20

## What the number means

The primary number is the share of the full weekly quota allocated to a planned session. It is neither a forecast of demand nor an additional quota limit enforced by Codex. Five-hour limits remain independent.

Observed consumption is influenced by task availability, model choice, quota constraints and the app's own warnings. Historical samples alone cannot distinguish sleeping, missing work, deliberate restraint and unobserved activity. No causal correction factor is inferred.

## Inputs and allocation

Let R be the current remaining weekly percentage, S the user's reserve, and H the earlier of the confirmed natural reset and earliest known available credit expiry. A credit deadline is a planning target for manual redemption, not a replenishment event.

Intersect user-confirmed local-time sessions with [now,H). For each session i, let h_i be its remaining elapsed hours and w_i its user-selected weight. Then:

```text
B = max(0, R - S)
A_i = B × (h_i × w_i) / sum(h_j × w_j)
```

Weights are 1 by default. The editor offers 0.5, 1 or 2 for the selected current date. Overnight sessions belong to their start date; equal start and end hours mean a full day. DST uses real elapsed hours. No scheduled time means no allowance, with a request to edit the plan.

At the first valid reading in an active session, freeze its allocation A and starting balance R_anchor:

```text
consumed = max(0, R_anchor - R_now)
allowance = min(max(0, R_now - S), max(0, A - consumed))
```

Time passing or observed pace falling cannot increase that frozen allocation. An overspent session shows zero and explains that further use draws from future sessions. At the next session, unused quota is reallocated from the actual balance.

A plan edit, time-zone change, confirmed reset, changed endpoint, or a balance above the anchor starts a new allocation. Sub-anchor corrections change the net observed consumption; the model cannot distinguish corrections from use within a missing interval. Ordinary restarts reuse the saved anchor.

## Freshness and boundaries

An OK snapshot no older than 180 seconds is required; snapshots more than 60 seconds in the future are rejected. Pending quota-change confirmation suspends advice. A reading from before the start of a new session or before an expired anchored deadline cannot fund its successor. Fresh post-expiry data may reallocate the actual remaining balance toward the next known endpoint; it never manufactures a full quota.

A five-hour exhausted reading takes priority in the primary status. Weekly allocations do not convert into five-hour units, model choices, task counts or guaranteed uninterrupted work.

## History and privacy

Account quota deltas include other devices' usage. They do not reveal which device or minute produced each change. Local observations remain observations, not a complete activity log.

Plans and anchors use local UserDefaults. Existing SQLite quota/credit history is retained. No schedule, anchor or inferred behavior is added to analytics.

## Validation and limits

Core regression tests cover conservation, freeze, idle time, reserve, partial sessions, overnight weekdays, DST, full-day schedules, plan weights, time zones, correction, invalid inputs and earlier credit deadlines. Native tests cover persistence, stale/confirmation/error states and boundary freshness.

Historical forecasting remains a secondary reference. See [its methodology](forecast-methodology.md). The browser lab retains that older model; it does not implement the native planner.

Future evaluation should record which advice was actually viewed, allow optional user reports of holding back, and compare quota left at reset with useful work completed. These measurements are not implemented in this release. Reduced waste and causal prediction accuracy have not been established. The product must not encourage unnecessary tasks solely to exhaust quota.
