# Competitor Trial Stage

Date: 2026-07-01

Follow-up synthesis:

- See `docs/research/competitors/2026-07-01-competitor-visual-and-product-archive.md` for the reusable visual archive, product-shape analysis, and product positioning summary.
- See `docs/product/strategy-and-commercialization.md` for the current product and commercialization strategy.

## Objective

Evaluate existing quota display tools before deciding whether Quota Capsule should continue independently, contribute upstream, or pivot.

## User Request

- Chrome version should start as an independent version.
- Read the pasted ChatGPT research.
- Pick safe projects for local setup and trial first.
- Then compare product overlap and decide whether to build independently or contribute to existing projects.

## Local Trial Workspace

External projects are kept outside this repository:

`/Users/Zhuanz/Documents/quota-competitor-lab`

## Safety Rules

- Prefer read-only source inspection before running any project.
- Do not run install scripts that modify shell profile, launch agents, browser profiles, auth state, or Codex binaries.
- Do not paste or expose API keys, cookies, tokens, Codex auth files, or raw session data.
- Prefer demo/mock/offline mode when available.
- Record any skipped project and the reason.

## Verified Repositories

| Project | URL | Local Path | Trial Status |
| --- | --- | --- | --- |
| QuotaGem | https://github.com/gyozalab/QuotaGem | `/Users/Zhuanz/Documents/quota-competitor-lab/QuotaGem` | Frontend dev server running at `http://127.0.0.1:5174/`; full app is Windows/Tauri and not run on this Mac. |
| Codex Quota Viewer | https://github.com/Half-Melon/Codex-Quota-Viewer | `/Users/Zhuanz/Documents/quota-competitor-lab/Codex-Quota-Viewer` | Swift release binary and `.app` built successfully. Not auto-opened because the app includes account/config/session mutation features. |
| ClaudeBar | https://github.com/tddworks/ClaudeBar | `/Users/Zhuanz/Documents/quota-competitor-lab/ClaudeBar` | Cloned and inspected only. Requires Tuist and full macOS app setup; not first safe trial. |
| codex-quota / CQ | https://github.com/deLiseLINO/codex-quota | `/Users/Zhuanz/Documents/quota-competitor-lab/codex-quota` | Built successfully. Safe mock TUI script created and tested. |
| opencode-quota | https://github.com/slkiser/opencode-quota | `/Users/Zhuanz/Documents/quota-competitor-lab/opencode-quota` | Built successfully with scripts disabled during install. `show --json` tested against isolated config. |

## Local Trial Entrypoints

Use these from `/Users/Zhuanz/Documents/quota-competitor-lab`:

```bash
./run-codex-quota-demo.sh
```

Runs `codex-quota` with a temporary fake HOME, fake Codex/OpenCode auth files, and the repository's mock usage server. It does not read or write the real `~/.codex`.

```bash
./run-opencode-quota-show.sh
```

Runs `opencode-quota show --provider synthetic --json` against an isolated OpenCode config directory. This currently reports `synthetic` as unavailable, which is expected without configured cache/auth.

```bash
./run-codex-quota-viewer-isolated.sh
```

Launches the built Codex Quota Viewer binary with an isolated fake HOME. Use only for UI inspection. The normal app has account switching, config writing, session management, and backup/rollback features.

Also available:

```text
http://127.0.0.1:5174/
```

QuotaGem frontend panel dev server. It is useful for inspecting visual density and provider layout, but it is not the real Windows tray app.

## Safety Notes

- QuotaGem production dependencies had 0 audit vulnerabilities after `npm install --ignore-scripts`; full Tauri/Windows runtime was not run.
- Codex Quota Viewer built successfully, but its bundled session manager dependencies reported audit vulnerabilities during competitor build. Treat as competitor-trial risk, not our project risk.
- Codex Quota Viewer and codex-quota both include account/config switching capabilities. Any real-data trial should avoid switch/apply/account mutation actions unless a separate backup is made first.
- ClaudeBar was not built because it requires Tuist and is a full multi-provider macOS app. It is valuable for architecture and UI reference but not the lowest-risk first trial.

## Findings

### Product Overlap

Quota Capsule overlaps with existing tools on quota visibility, 5h/weekly windows, reset time, provider adapters, and colored state. The overlap is real.

The clearest direct competitor for the Windows route is QuotaGem. It already has:

- Windows tray-first product shape.
- Compact and expanded panels.
- Claude, Codex, and Antigravity providers.
- 5h and weekly usage.
- Codex app-server source, with `.codex/sessions` JSONL fallback.
- Warning/danger thresholds, notifications, theme controls, launch-at-login.

Codex Quota Viewer overlaps strongly on macOS menu bar and Codex data source. It is much heavier: account vault, account switching, config writing, local session manager, repair/rollback.

codex-quota overlaps on data and account management, but it is a terminal product, not a consumer-facing always-visible UI.

opencode-quota overlaps on provider breadth and quota command surfaces. It is integrated into OpenCode, not a standalone desktop capsule.

ClaudeBar overlaps on macOS menu bar multi-provider status, but its product thesis is broad monitoring, not a single calm capsule.

### Difference Worth Preserving

Quota Capsule should not compete as "yet another quota dashboard." The viable difference is:

- A tiny default-on floating capsule.
- A direct human judgment: safe, watch, danger, unknown.
- Time progress vs quota-used comparison as the core visual explanation.
- 5h window as the primary status; weekly quota as secondary pressure.
- Chrome extension as an independent lightweight distribution path.
- Codex-first but adapter-friendly, without becoming multi-account/session-management software.

### Data Source Implication

Both QuotaGem and Codex Quota Viewer confirm that `codex app-server` plus JSON-RPC method `account/rateLimits/read` is a practical source path. Codex Quota Viewer launches Codex with read-only/untrusted sandbox arguments for this path, and QuotaGem maps `usedPercent`, `windowDurationMins`, and `resetsAt` into usage windows.

Quota Capsule should upgrade its current source probe from CLI-help inspection to a read-only app-server rate-limit probe.

### Build Or Contribute?

Recommendation: build Quota Capsule independently, but contribute back narrow fixes or source-adapter learnings if we find useful patches.

Reasons:

- The UX goal is different enough. Existing projects are dashboards, menu bars, TUI/account managers, or OpenCode plugins.
- QuotaGem is close on Windows, but its product is multi-provider tray monitoring. It is not optimized around a tiny floating "can I keep going?" capsule.
- Codex Quota Viewer is too broad and mutates Codex config/session state; using it as the base would pull Quota Capsule into a heavier product category.
- opencode-quota is excellent as an integration/plugin reference, but it is not a desktop overlay product.

## Product Decision Draft

Continue Quota Capsule as a standalone project with this narrower framing:

> Codex-first floating quota capsule. It does not manage accounts. It does not switch auth. It does not become a full dashboard by default. It answers whether the current pace can reach reset, with optional detail on demand.

Chrome version should start as an independent version. Mac local version should prioritize floating capsule plus optional menu bar mode. Windows native version stays later, after Mac/Chrome feedback.

## Next Recommended Work

1. Add a Codex app-server rate-limit probe to `packages/source-codex`.
2. Add a competitor matrix to README or docs, honestly positioning Quota Capsule against QuotaGem, ClaudeBar, Codex Quota Viewer, codex-quota, and opencode-quota.
3. Prototype Chrome independent extension around a mock source first, then real source if the browser can safely access a reliable source.
4. Keep account switching and session management explicitly out of MVP scope.
