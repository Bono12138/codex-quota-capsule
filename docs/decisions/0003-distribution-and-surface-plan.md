# Decision 0003: Distribution And Surface Plan

Date: 2026-07-01

## Decision

Quota Capsule will pursue three product routes, but not with equal priority.

Priority order:

1. Chrome independent version.
2. Mac local version with floating capsule as default and menu bar as optional display mode.
3. Windows native version later, after Chrome/Mac feedback.

## Rationale

Chrome first:

- One build can reach Mac, Windows, and Linux users.
- It lets the project validate the product idea before native Windows packaging.
- It can start mock-first while source feasibility is proven.

Mac local:

- The founder/user can use it daily.
- Real usage can drive design iteration and social content.
- Floating capsule directly serves the "always visible without clicking" requirement.

Windows later:

- Windows native work is still important, but QuotaGem already covers the tray-dashboard direction.
- Native Windows packaging, autostart, notifications, and trust require a bigger investment.
- It should follow clearer demand signals.

## Consequences

- `apps/chrome-extension` should be added as an independent app, not only as a companion to the desktop app.
- `apps/desktop` remains useful for Mac/local visual exploration and later native shells.
- MVP language should not imply Windows is the immediate P1 deliverable.
- Product copy should say Codex-first, not Codex-only.
- The default UI should be a persistent capsule, not a dashboard.

