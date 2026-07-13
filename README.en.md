# Quota Capsule / 额度胶囊

Languages: [简体中文](README.zh-CN.md) | [English](README.en.md)

Quota Capsule is a small macOS quota runway capsule for heavy Codex users. It turns raw quota-window data into the working decision users actually need:

> At the current pace, can I keep working until the next reset?

Codex is the first supported provider, and the architecture remains agent-extensible. Other agent communities can contribute local source adapters while reusing the shared quota model, prediction engine, UI states, and product surface.

## Why It Exists

Heavy Codex users often run several coding tasks at the same time and repeatedly check usage pages. A bare percentage is evidence. The working decision is:

- Can I keep using Codex right now?
- Can the current pace last until reset?
- If it may not last, what does the risk range look like?
- If it can last, how much margin should remain at reset?

Quota Capsule stays small, visible, and direct with six honest states:

- Early estimate: the first valid weekly reading produces a wide, low-confidence range.
- On track: the conservative forecast band still lasts until weekly reset.
- Running fast: it may still last, but the forecast margin is thin.
- May run out: both the fast and slow estimates can exhaust before reset.
- Exhausted: this week's quota is gone and will recover at reset.
- Data unavailable: the live read failed or expired; frozen percentages remain visible without a pace claim.

## Who It Is For

- Codex users who often run several tasks at once.
- People who repeatedly check quota or usage pages while working.
- Developers who want a local-first quota gauge they can inspect and modify.
- Agent communities that want to add their own quota source adapters.

## Current Status

The first local macOS beta is usable. It includes:

- Native floating desktop capsule.
- Menu bar status item.
- Read-only Codex app-server rate-limit adapter.
- Weekly pace, actual last-24-hour usage, reset-buffer range, and a next-24-hour budget.
- Current-cycle trend with a sustainable line, forecast band, and reset marker.
- Local history snapshots.
- Multilingual UI.
- Public feedback links.

The native macOS app uses real local Codex rate-limit data. The browser/Vite demo remains as a visual prototype and exploration path for future Web or Chrome versions.

## Quick Start

Codex-assisted installation is the recommended early public test path. Open this repository and give the prompt below to your own Codex:

```text
Please install and run Quota Capsule on this Mac:
1. Open https://github.com/Bono12138/codex-quota-capsule
2. Read README.md, INSTALL.md, AGENTS.md, and package.json first.
3. Do not modify my Codex login state, log me out, reinstall Codex, or replace Codex binaries.
4. Only do local clone, dependency install, build, test, and launch.
5. Do not read, copy, print, or upload auth tokens, cookies, API keys, prompt text, session text, code content, or private file paths.
6. If Node, npm, Swift, Xcode Command Line Tools, or Codex CLI is missing, tell me before changing the system.
7. Run npm ci.
8. Run npm test.
9. Run npm run build.
10. Run swift run QuotaCapsuleCoreSpec.
11. Run npm run mac:install and verify that exactly one running process comes from /Applications.
12. After it launches, tell me how to open it again.
```

Manual install:

```bash
git clone https://github.com/Bono12138/codex-quota-capsule.git
cd codex-quota-capsule
npm ci
npm test
npm run build
swift run QuotaCapsuleCoreSpec
npm run mac:install
```

## One App

The repository builds one `Quota Capsule Beta.app`. Development uses branches, tests, and previews instead of installing a second persistent application.

Run the native macOS Beta:

```bash
npm run mac:run
```

## Privacy Boundary

- By default, the app reads and computes locally.
- Product events are not uploaded unless an analytics endpoint is configured.
- If an analytics endpoint is configured, basic diagnostics and product improvement data are sent in separate tiers.
- Prompt text, session text, code content, private file paths, account credentials, auth tokens, and cookies stay on this Mac.
- Missing or stale data is shown as `Data unavailable`, with stale percentages clearly marked.

## Project Structure

```text
Sources/QuotaCapsuleMac/   Native macOS floating capsule and menu bar app.
Sources/QuotaCapsuleCore/  Swift provider-neutral model, prediction, and Codex app-server source.
apps/desktop/              Vite desktop UI mock for Web/Chrome exploration.
packages/core/             Provider-neutral quota model, prediction engine, and status copy.
packages/source-codex/     Codex-first local source probe and future adapter.
packages/analytics-collector/ Optional product improvement data receiver.
docs/product/              Product brief, MVP scope, roadmap, and acceptance criteria.
docs/distribution/         Distribution strategy, public repo manifest, and launch materials.
docs/decisions/            Project decision records.
scripts/                   Local helper scripts.
```

## Roadmap

- Better onboarding and in-product guidance.
- Longer-term history and usage-rhythm review.
- Chrome version.
- More agent provider adapters.
- Signed, notarized, packaged macOS distribution after the beta stabilizes.

## Feedback

- GitHub Issues: <https://github.com/Bono12138/codex-quota-capsule/issues>
- Email: `mmz1218bono@gmail.com`
- X: <https://x.com/starlightsz0>
- Douyin: 火腿肠 (`huotuichang439`)

You can also follow on Douyin and send feedback there:

![Douyin QR code](docs/assets/douyin-qr-scan.png)

## License

MIT. See [LICENSE](LICENSE).
