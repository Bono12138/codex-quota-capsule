# Quota Capsule

Languages: [简体中文](README.zh-CN.md) | [English](README.en.md)

Quota Capsule is a Codex-first desktop quota gauge. It turns raw quota-window data into the question users actually care about:

> At the current pace, can I make it to the next reset? If not, when will I run out?

Codex is the first supported provider, but the architecture is agent-extensible. Other agent communities can contribute local source adapters while reusing the shared quota model, prediction engine, UI states, and product surface.

## Why It Exists

Heavy agent users often run several coding tasks at the same time and repeatedly check usage pages. A bare percentage is not enough: "40% remaining" does not say whether the current pace is sustainable.

Quota Capsule is designed to stay small, visible, and direct:

- Safe: likely enough quota to reach reset.
- Watch: usable for now, but the margin is thin.
- Danger: likely to run out before reset.
- Unknown: the data source is missing, stale, or unreadable.

## Current Status

The first local macOS beta is usable. It includes the core model, prediction engine, read-only Codex app-server rate-limit adapter, snapshot recording, Quiet Glass Capsule UI, menu bar entry, and distributable zip packaging.

The native macOS app uses real local Codex rate-limit data. The browser/Vite demo remains as a visual prototype and exploration path for future Web or Chrome versions.

## Project Structure

```text
Sources/QuotaCapsuleMac/   Native macOS floating capsule and menu bar app.
Sources/QuotaCapsuleCore/  Swift provider-neutral model, prediction, and Codex app-server source.
apps/desktop/              Vite desktop UI mock for Web/Chrome exploration.
packages/core/             Provider-neutral quota model, prediction engine, and status copy.
packages/source-codex/     Codex-first local source probe and future adapter.
docs/product/              Product brief, MVP scope, roadmap, and acceptance criteria.
docs/research/             Source validation.
docs/decisions/            Project decision records.
scripts/                   Local helper scripts.
```

## Codex-First, Agent-Extensible

The first version serves Codex because that is the clearest current pain point.

The public positioning should not lock the project to Codex only:

- Codex is the first supported provider.
- Each source adapter is provider-specific.
- The core prediction logic is provider-neutral.
- Other agent communities are welcome to adapt their own quota windows and quota semantics.

## Local Development

Codex-assisted installation is the recommended early public test path. See [INSTALL.md](INSTALL.md) for details.

```bash
npm ci
npm test
npm run build
npm run dev
```

Run the native macOS beta:

```bash
npm run mac:run:internal-test
```

Build the public beta macOS zip:

```bash
npm run mac:package:internal-test
```

Output:

```text
dist/internal-test/Quota-Capsule-Beta-macOS.zip
```

The local beta and development builds are separated:

```bash
# Internal test build: defaults to public GitHub Issues
npm run mac:run:internal-test

# Development build: private issue URL must be configured explicitly
QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL="https://github.com/<owner>/<private-repo>/issues" npm run mac:run:dev
```

Run the read-only Codex rate-limit probe:

```bash
npm run probe:codex:rate-limits
```

This command calls `account/rateLimits/read` through `codex -s read-only -a untrusted app-server` and prints a sanitized quota snapshot, prediction, and local snapshot record. It does not read prompts, session text, or auth tokens.

## Feedback

- GitHub Issues: <https://github.com/Bono12138/codex-quota-capsule/issues>
- Email: `mmz1218bono@gmail.com`
- X: <https://x.com/starlightsz0>
- Douyin: 火腿肠 (`huotuichang439`)

You can also follow on Douyin and send feedback there:

![Douyin QR code](docs/assets/douyin-qr-scan.png)

## Privacy Boundary

- By default, the app reads and computes locally.
- Product events are not uploaded unless an analytics endpoint is configured.
- If an analytics endpoint is configured, basic diagnostics and product improvement data are sent in separate tiers. Prompts, session text, code, file paths, and account credentials stay on this Mac.
- The app does not collect account content.
- The app does not record auth tokens, cookies, private keys, or session file contents.
- Missing or stale data is shown as `unknown`, never as `safe`.

## License

MIT. See [LICENSE](LICENSE).
