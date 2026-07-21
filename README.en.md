# Quota Capsule / 额度胶囊

Languages: [简体中文](README.zh-CN.md) | [English](README.en.md) | [Bilingual](README.md)

**A local-first macOS quota runway assistant for heavy Codex users.**

> At the current pace, can I keep working until the next weekly reset?

![Quota Capsule collapsed and expanded](docs/assets/product/quota-capsule-expanded.png)

## Why It Exists

A quota percentage tells you how much has been used. It does not tell you whether the remaining quota can support the way you are working now.

Heavy AI-native users may run several tasks at once, repeatedly check the usage page, hold back even when paid quota is still available, or discover too late that a large balance will expire at reset. Quota Capsule closes that judgment gap by comparing quota usage with elapsed time, recent pace, current activity, and available history.

It reports six honest states—Early estimate, On track, Running fast, May run out, Exhausted, and Data unavailable—plus a next-24-hour budget and a forecast range for the balance at reset.

Codex is the first supported provider, and the architecture remains agent-extensible. Other agent communities can contribute local source adapters while reusing the shared quota model, prediction engine, UI states, and product surface.

## Product Surfaces

Quota Capsule is designed to stay quiet until the user needs more detail:

- A small floating desktop capsule with the current judgment and weekly usage.
- A menu bar status item for glanceable, always-available context.
- An expanded panel with time and usage progress, pace evidence, forecast confidence, a sustainable line, reset timing, and local history.

![Quota Capsule collapsed](docs/assets/product/quota-capsule-collapsed.png)

![Quota Capsule in the macOS menu bar](docs/assets/product/quota-capsule-menu-bar.png)

## Current Beta

The current public prerelease is [v0.3.4-beta.1](https://github.com/Bono12138/codex-quota-capsule/releases/tag/v0.3.4-beta.1). It includes:

- Native floating desktop capsule and menu bar item.
- Read-only Codex app-server rate-limit source.
- Immediate first-reading estimates with adaptive cycle, recent, activity, and historical evidence.
- Next-24-hour budget, actual last-24-hour usage, reset-balance range, and a plain-language confidence reason.
- Separate weekly-reset, last-successful-read, and next-automatic-read timing.
- Current-cycle trend with a sustainable line, forecast band, and reset marker.
- Local history snapshots and privacy-safe reset-credit count, expiry timing, and lifecycle history.
- Multilingual UI and public feedback links.

See [Forecast Methodology](docs/product/forecast-methodology.md) for equations, uncertainty, confidence, stale behavior, limits, and change control.

## Install

### Download the current beta

Download `Quota-Capsule-Beta-macOS.zip` from the [v0.3.4-beta.1 release](https://github.com/Bono12138/codex-quota-capsule/releases/tag/v0.3.4-beta.1).

The current beta uses ad-hoc signing and is not yet notarized. macOS may require opening the app from Finder with **Right-click → Open**. See [INSTALL.md](INSTALL.md) for system requirements and Gatekeeper guidance.

<details>
<summary>Codex-assisted installation</summary>

```text
Please install and run Quota Capsule on this Mac:
1. Open https://github.com/Bono12138/codex-quota-capsule
2. Read README.md, INSTALL.md, AGENTS.md, and package.json first.
3. Do not modify my Codex login state, log me out, reinstall Codex, or replace Codex binaries.
4. Only do local clone, dependency install, build, test, and launch.
5. Do not read, copy, print, or upload auth tokens, cookies, API keys, prompt text, session text, code content, or private file paths.
6. If Node, npm, Swift, Xcode Command Line Tools, or Codex CLI is missing, tell me before changing the system.
7. Run npm ci, npm test, npm run build, npm run audit:repository, swift test, and swift run QuotaCapsuleCoreSpec.
8. Run npm run mac:install and verify that exactly one running process comes from /Applications.
9. After it launches, tell me how to open it again.
```

</details>

<details>
<summary>Build from source</summary>

```bash
git clone https://github.com/Bono12138/codex-quota-capsule.git
cd codex-quota-capsule
npm ci
npm test
npm run build
npm run audit:repository
swift test
swift run QuotaCapsuleCoreSpec
npm run mac:install
```

</details>

## Privacy Boundary

- Quota data is read and computed locally by default.
- Product events are not uploaded unless an analytics endpoint is explicitly configured and the relevant consent is enabled.
- Prompt text, session text, code content, private file paths, account credentials, auth tokens, and cookies stay on this Mac.
- Reset-credit raw IDs, descriptions, and referral payloads are not stored; only a SHA-256 identity fingerprint and safe timestamps/status facts remain in local history until the user clears it.
- Missing or stale quota data is shown as `Data unavailable`; stale percentages never produce a new safety judgment.

## Reuse and Integration

Quota Capsule is MIT-licensed. Another macOS product can adopt the whole project or reuse selected layers:

- `Sources/QuotaCapsuleCore/`: provider-neutral Swift quota model, forecasting, history, and the read-only Codex source.
- `Sources/QuotaCapsuleMac/`: native floating capsule, expanded panel, menu bar surface, settings, and local persistence.
- `packages/core/` and `packages/source-codex/`: TypeScript model and source packages for Web, Chrome, or adapter exploration.
- `docs/product/`: product contract, forecast methodology, acceptance criteria, and edge-case decisions.

You are welcome to integrate, modify, merge, or redistribute the code under the terms of [LICENSE](LICENSE). Contributions for other agent-provider adapters are also welcome.

## Project Structure

```text
Sources/QuotaCapsuleMac/   Native macOS floating capsule and menu bar app.
Sources/QuotaCapsuleCore/  Swift provider-neutral model, forecasting, and Codex source.
apps/desktop/              Vite UI mock for Web/Chrome exploration.
packages/core/             TypeScript provider-neutral model and prediction engine.
packages/source-codex/     Codex-first local source probe.
docs/product/              Product brief, forecast methodology, roadmap, and acceptance criteria.
docs/decisions/            Project decision records.
```

## Roadmap

- Better onboarding and in-product guidance.
- Longer-term history and usage-rhythm review.
- Chrome version.
- More agent-provider adapters.
- Signed, notarized, packaged macOS distribution after the beta stabilizes.

## Feedback

- GitHub Issues: <https://github.com/Bono12138/codex-quota-capsule/issues>
- Email: `mmz1218bono@gmail.com`
- X: <https://x.com/starlightsz0>
- Douyin: 火腿肠 (`huotuichang439`)

<img src="docs/assets/douyin-qr-scan.png" alt="Douyin QR code" width="180" />

## License

MIT. See [LICENSE](LICENSE).
