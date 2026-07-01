# Quota Capsule

Quota Capsule is a Codex-first desktop quota gauge. It turns raw usage-window data into the answer users actually need:

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

The first engineering gate is not UI polish. It is proving whether Codex quota data can be read locally, reliably, and without collecting sensitive account data. Until that is proven, the desktop UI uses mock data.

## Project Shape

```text
apps/desktop/              Vite desktop UI mock; future Tauri/Electron shell lives here.
packages/core/             Provider-neutral quota model, prediction engine, and status copy.
packages/source-codex/     Codex-first local data-source probe and future adapter.
docs/product/              Product brief, MVP scope, release framing.
docs/research/             Data-source verification notes and probe plan.
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
5. Add a real Codex source adapter only after the probe is proven.
6. Package the Windows MVP.

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

