# Contributing

Quota Capsule welcomes contributions for Codex and other agent products.

## Good First Areas

- Mock data scenarios for different quota windows.
- Provider source adapters.
- UI states and copy packs.
- Windows packaging tests.
- Documentation and privacy review.

## Planning And Triage

- Track executable bugs and feature work in GitHub Issues.
- Use `docs/product/bug-triage-and-release-blockers.md` for priority and release-blocker rules.
- Use `docs/product/feature-roadmap.md` for accepted, deferred, and rejected product direction.
- Do not duplicate full issue status in Markdown docs.

## Adapter Rules

Provider adapters must:

- Run locally by default.
- Return structured data or a structured error.
- Avoid logging secrets, cookies, account identifiers, or raw credentialed files.
- Mark stale data as stale.
- Never automate quota resets or upstream account actions.

## Project Layout

- Put shared quota types and prediction logic in `packages/core`.
- Put Codex-specific code in `packages/source-codex`.
- Put future provider adapters under `packages/source-<provider>`.
- Put desktop shell code in `apps/desktop`.

## Before Opening A PR

```bash
npm test
npm run build
npm run lint
```
