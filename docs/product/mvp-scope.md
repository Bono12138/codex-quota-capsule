# MVP Scope

## P0

- Provider-neutral quota model.
- Prediction engine with safe/watch/danger/unknown states.
- Mock scenarios for safe, watch, danger, just-reset, stale, and source-error cases.
- Read-only Codex local source probe.
- Desktop UI mock that renders compact and detailed states.
- Chrome independent mock-first extension scaffold.
- Privacy README and adapter contribution rules.

## P1

- Read-only `codex app-server` rate-limit adapter.
- Mac floating capsule prototype.
- Mac menu-bar display mode.
- Chrome extension source feasibility proof.
- Position persistence.
- Settings persistence.

## P2

- Windows always-on-top capsule shell.
- Windows tray icon and menu.
- Windows installer.
- Theme packs.
- Copy packs.
- Historical trend view.

## Public Release Blockers

- Codex source cannot be read reliably.
- Source failure still shows safe/green.
- App cannot be exited cleanly.
- Installer cannot be uninstalled.
- Privacy boundaries are not documented.
