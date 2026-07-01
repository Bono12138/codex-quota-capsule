# Competitor, Visual, And Product Archive

Date: 2026-07-01

## Purpose

This document captures the competitor research, local trial setup, visual review, and product conclusions behind Quota Capsule.

It is meant to avoid repeating the same discovery work later. When revisiting product shape, visual design, or market positioning, start here and then open the linked local trial workspace only if fresh verification is needed.

## Scope

Reviewed projects:

- QuotaGem: `https://github.com/gyozalab/QuotaGem`
- ClaudeBar: `https://github.com/tddworks/ClaudeBar`
- Codex Quota Viewer: `https://github.com/Half-Melon/Codex-Quota-Viewer`
- codex-quota / CQ: `https://github.com/deLiseLINO/codex-quota`
- opencode-quota: `https://github.com/slkiser/opencode-quota`

Local trial workspace:

```text
/Users/Zhuanz/Documents/quota-competitor-lab
```

## Screenshot Archive

Public repository boundary:

- Only Quota Capsule's own screenshot is stored in this repository.
- Third-party screenshots are kept in ignored local state because several reviewed repositories do not currently expose a clear root `LICENSE` file in the local clone.
- Do not publish copied third-party screenshots from `local-state/` without checking license and attribution first.

Quota Capsule current demo:

![Quota Capsule current demo](assets/quota-capsule-current-demo.png)

Local third-party visual archive:

```text
/Users/Zhuanz/Documents/codex-quota-capsule/local-state/competitor-visual-archive/
```

Representative files in that local archive:

| Project | Local Screenshot | What It Shows |
| --- | --- | --- |
| QuotaGem | `local-state/competitor-visual-archive/quotagem-compact-panel.png` | Compact Windows-style panel with circular usage rings for multiple providers. |
| QuotaGem | `local-state/competitor-visual-archive/quotagem-expanded-panel.png` | Expanded multi-provider panel with 5h and weekly rows. |
| QuotaGem | `local-state/competitor-visual-archive/quotagem-settings-panel.png` | Settings panel for language, display mode, thresholds, and notifications. |
| ClaudeBar | `local-state/competitor-visual-archive/claudebar-dashboard-dark.png` | Polished macOS menu-bar dashboard with tabs, cards, and strong gradient styling. |
| ClaudeBar | `local-state/competitor-visual-archive/claudebar-dashboard-light.png` | Light variant of the same dashboard. |
| Codex Quota Viewer | `local-state/competitor-visual-archive/codex-quota-viewer-menu.png` | Native macOS menu-bar quota/account surface. |
| Codex Quota Viewer | `local-state/competitor-visual-archive/codex-quota-viewer-session-manager.png` | Bundled local session manager, showing the product's broader scope. |
| codex-quota | `local-state/competitor-visual-archive/codex-quota-tui-demo.png` | Terminal TUI quota/account view. |
| codex-quota | `local-state/competitor-visual-archive/codex-quota-tui-demo.gif` | TUI interaction demo. |

Source screenshot paths remain available in the competitor lab:

```text
/Users/Zhuanz/Documents/quota-competitor-lab/QuotaGem/docs/images/
/Users/Zhuanz/Documents/quota-competitor-lab/ClaudeBar/docs/screenshots/
/Users/Zhuanz/Documents/quota-competitor-lab/Codex-Quota-Viewer/docs/images/
/Users/Zhuanz/Documents/quota-competitor-lab/codex-quota/
```

## Product Shapes

### QuotaGem

Actual product shape:

- Windows tray application.
- Tray icon opens compact or expanded panels.
- Not a Chrome extension.
- Local dev server at `http://127.0.0.1:5174/` is only a frontend preview, not the real production surface.

What it proves:

- The Windows tray route already has a serious competitor.
- Users can understand provider quota through compact rings.
- 5h and weekly windows can coexist in one interface.
- `codex app-server` is a practical Codex quota source.

Where it differs from Quota Capsule:

- Multi-provider monitor first.
- Dashboard/panel interaction first.
- Uses threshold-style warning/danger logic rather than making quota pacing the central user-facing idea.
- It does not default to a tiny always-visible "can I keep working?" capsule.

Visual notes:

- The compact ring design is attractive and glanceable.
- The expanded panel looks richer than a raw settings tool, but it is still an opened panel.
- The forest/glass visual treatment is distinctive, but it may not match Quota Capsule's quieter work-surface goal.

### ClaudeBar

Actual product shape:

- Native macOS menu-bar application.
- Click menu bar icon to view a polished quota dashboard.
- Supports many AI coding assistants and themes.

What it proves:

- Quota tooling can be visually polished enough for daily use.
- Pace-aware quota logic is already a serious design area.
- Themes and menu-bar presence can be adoption features for power users.

Where it differs from Quota Capsule:

- Broad macOS AI usage monitor.
- Dashboard-heavy.
- More visually expressive than an ambient working indicator.
- Not optimized around a single Codex-first floating capsule.

Visual notes:

- Best visual polish among reviewed competitors.
- Strong gradients and cards make it feel like a real product, not a script.
- Too much dashboard energy for Quota Capsule's default state.

### Codex Quota Viewer

Actual product shape:

- Native macOS menu-bar app.
- Includes quota view, account vault, safe account switching, config writing, and bundled session manager.

What it proves:

- A native Codex-specific Mac app is viable.
- `account/rateLimits/read` through `codex app-server` is a credible data source.
- Staleness and read-failure states matter.

Where it differs from Quota Capsule:

- It is a Codex local management center, not a quota pacing assistant.
- It mutates local Codex configuration and manages accounts/sessions.
- The interaction burden and trust burden are much higher.

Visual notes:

- Practical and system-like.
- Good reference for local-management density, not for the default Quota Capsule UI.
- Session manager screenshots show why Quota Capsule should explicitly avoid becoming a session/account manager.

### codex-quota / CQ

Actual product shape:

- Terminal TUI.
- Built for account switching and quota monitoring.

What it proves:

- Developer users tolerate keyboard-first quota/account tools.
- A compact terminal quota display can be readable.
- Mock/demo mode is useful for safe trial.

Where it differs from Quota Capsule:

- Not consumer-facing.
- Not always visible unless the terminal remains open.
- TUI style should not drive the main product visual direction.

Visual notes:

- Clear for terminal users.
- Not a design reference for a beautiful floating capsule.

### opencode-quota

Actual product shape:

- OpenCode plugin plus CLI.
- Provides sidebar panel, toasts, compact status line, slash commands, and terminal `show`.

What it proves:

- Embedding quota into the work surface is valuable.
- Users may want to choose between sidebar, toast, compact status, or command-only surfaces.
- Distribution through `npx` and config installation is practical inside a tool ecosystem.

Where it differs from Quota Capsule:

- It is not a standalone desktop or browser surface.
- It follows OpenCode's UI constraints.
- It is more of an integration layer than an independent ambient product.

Visual notes:

- Good product-surface lesson: quota should live where work happens.
- Less useful as a visual reference for a standalone desktop capsule.

## Data Source Lessons

Most important confirmed source path:

```text
codex app-server
JSON-RPC initialize
account/rateLimits/read
```

Useful fields observed in competitor code:

- `usedPercent`
- `windowDurationMins`
- `resetsAt`
- `primary`
- `secondary`

Practical implication:

- Quota Capsule should upgrade `packages/source-codex` from CLI-help probing to a read-only app-server quota probe.
- The adapter should classify 5h vs weekly by `windowDurationMins`, not by assuming primary/secondary order.
- Source failure must produce an unknown/gray state, never a false-safe state.

## Product Overlap

Quota Capsule overlaps with competitors on:

- Showing quota status.
- Showing 5h and weekly windows.
- Showing reset time.
- Using green/yellow/red or similar status colors.
- Supporting local provider adapters.

The overlap is real and should be acknowledged in public positioning.

## Defensible Difference

Quota Capsule should not compete as "another quota dashboard."

The defensible difference is:

- Default always-visible floating capsule.
- Codex-first user problem.
- Pacing judgment as the primary value.
- Time progress vs quota-used comparison as the core explanation.
- One-line human answer before numeric detail.
- No account switching in MVP.
- No session manager in MVP.
- No default complex dashboard.

The core product promise:

> Quota Capsule turns quota from a static number into a runway judgment: can the current burn rate survive until reset?

## Visual Direction

Do:

- Make the first state tiny, calm, and glanceable.
- Use status color as a thin accent, not a full-screen theme.
- Prefer one strong sentence over many metrics.
- Use a detailed popover only when the user asks why.
- Keep 5h as primary; show weekly only as secondary pressure or in expanded view.
- Design around working beside Codex, IDEs, browser tabs, and terminals.

Avoid:

- A generic admin dashboard.
- A large landing-page style hero.
- Heavy decorative gradients as the product surface.
- Multi-card density in the default state.
- Account/session management in the core product.
- Copying competitor visual assets or layout too closely.

## Current Quota Capsule UI Assessment

The current demo is directionally correct because it shows:

- Safe/watch/danger/unknown.
- Human-language verdicts.
- Time progress and quota used as separate bars.

But it is still a demo screen, not the final product surface:

- It displays four states side by side, which is useful for testing but not a real user workflow.
- The cards look more like product spec examples than a polished floating capsule.
- The default production state should be one compact capsule with a click/hover detail layer.

## Product Decision

Continue building Quota Capsule independently.

Reasoning:

- Competitors validate demand but do not own the exact ambient capsule experience.
- The data-source technique can be learned without inheriting their product scope.
- Forking or basing on heavier products would pull Quota Capsule into account/session/dashboard territory.
- The public open-source story is cleaner if Quota Capsule owns its design thesis and invites adapters.

Upstream contribution remains useful, but only as a side path:

- Contribute small source-adapter fixes.
- Share read-only Codex app-server findings.
- Avoid turning Quota Capsule into a feature PR inside another dashboard.

## Open Questions

- Can a Chrome extension safely and reliably read or receive quota data without a local helper?
- Should the Chrome version be only an in-page/browser toolbar indicator, or also support a small overlay?
- How much weekly quota should be visible in the default capsule before it becomes noise?
- Should Mac local MVP use floating capsule first, menu bar first, or both from the start?
- What exact copy best expresses safe/watch/danger in English and Chinese?

