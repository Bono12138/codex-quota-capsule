# Quota Capsule

Quota Capsule is a Codex-first quota runway capsule. It turns raw usage-window data into the answer users actually need:

> At the current pace, can I make it to the next reset? If not, when will I run out?

The first target is Codex. The project is intentionally agent-extensible: other agent products can add their own local source adapters and reuse the same quota model, prediction engine, UI states, and desktop shell.

## Why This Exists

Heavy agent users often keep several coding tasks running and repeatedly check usage pages because simple percentages are not enough. A remaining quota number does not say whether the current pace is safe.

Quota Capsule aims to be a tiny always-visible capsule that says the useful thing directly:

- Safe: likely enough until reset.
- Watch: enough for now, but not much buffer.
- Danger: likely runs out before reset.
- Unknown: data source is missing, stale, or unreadable.

## Current Status

This repository is in project bootstrap state.

The first engineering gates are source proof and product-surface proof: Codex quota data must be read locally and safely, and the UI must be good enough to stay visible during real work. Until source proof is complete, UI surfaces use mock data.

## Project Shape

```text
apps/desktop/              Vite desktop UI mock; future native shell exploration lives here.
packages/core/             Provider-neutral quota model, prediction engine, and status copy.
packages/source-codex/     Codex-first local data-source probe and future adapter.
docs/product/              Product brief, MVP scope, strategy, commercialization.
docs/research/             Data-source verification, competitor, and visual research notes.
docs/decisions/            Durable project decisions.
scripts/                   Local helper scripts.
```

## Codex-First, Agent-Extensible

The product is designed for Codex first because that is the immediate pain. The public framing should stay broader:

- Codex is the first supported provider.
- Source adapters are provider-specific.
- Core prediction logic is provider-neutral.
- Other agent communities are welcome to adapt the product for their own usage windows and quota semantics.

## First Development Gates

1. Confirm readable local Codex usage fields, or record that the source is unavailable.
2. Lock the shared quota data model.
3. Build and test the prediction engine with mock data.
4. Build the small always-visible capsule UI with mock states.
5. Add the Chrome independent version as a mock-first app.
6. Add a real Codex source adapter only after the probe is proven.
7. Prototype Mac floating capsule and menu-bar display modes.
8. Keep Windows native packaging for a later demand-driven phase.

## Product Research

- [Product brief](docs/product/brief.md)
- [MVP scope](docs/product/mvp-scope.md)
- [Product strategy and commercialization](docs/product/strategy-and-commercialization.md)
- [Competitor visual and product archive](docs/research/competitors/2026-07-01-competitor-visual-and-product-archive.md)
- [Competitor local trial notes](docs/research/competitors/2026-07-01-competitor-trial-stage.md)

## Local Development

```bash
npm install
npm test
npm run build
npm run dev
```

Run the current Codex probe:

```bash
npm run probe:codex
```

The probe is intentionally conservative. It records what the local Codex CLI exposes and must not scrape secrets, log auth tokens, or pretend old data is fresh.

## Privacy Posture

- Read and calculate locally by default.
- Do not upload usage data.
- Do not collect account content.
- Do not log auth tokens, cookies, private keys, or session files.
- Treat missing or stale data as `unknown`, not as safe.

## License

MIT
