# Contributing

Quota Capsule welcomes public contributions for Codex and other agent products.

## One Repository

`Bono12138/codex-quota-capsule` is the only source of truth. Work on a short-lived branch, open a pull request, and delete the branch after merge. Do not create a parallel source repository or copy changes through a staging tree.

## Good First Areas

- Weekly forecast fixtures for sparse, bursty, idle, stale, and reset states.
- Provider source adapters.
- Accessibility and multilingual copy review.
- Installation, privacy, and release-audit tests.
- Documentation improvements.

## Project Boundaries

- Shared quota types and prediction logic: `packages/core` and `Sources/QuotaCapsuleCore`.
- Codex-specific source code: `packages/source-codex` and the native Codex client.
- Native macOS shell: `Sources/QuotaCapsuleMac`.
- Public product decisions: `docs/decisions`.
- Current operations: `docs/operations`.

Provider adapters must run locally by default, return structured data or structured errors, mark stale data explicitly, and never log credentials or automate upstream account actions.

## Development Flow

1. Create `codex/<short-feature-name>` from current public `main`.
2. Write a failing regression or feature test.
3. Implement the smallest change that makes it pass.
4. Update user-facing and engineering documentation in the same branch.
5. Run the complete checks below.
6. Confirm every commit uses the intended contributor identity.
7. Open a pull request and wait for required CI.

## Required Checks

```bash
npm test
npm run build
npm run lint
npm run audit:repository
npm run audit:weekly-only
swift test
swift run QuotaCapsuleCoreSpec
swift build --product QuotaCapsuleMac
git diff --check
```

UI changes also require deterministic state screenshots and a real macOS interaction pass. Build success alone is not product acceptance.

## Privacy

Never commit credentials, auth state, authenticated raw responses, prompt/session text, code content, local databases, crash logs, absolute personal paths, or private repository addresses. Public documents should preserve decisions and reproducible evidence without exposing private working context.

See [docs/README.md](docs/README.md), [ADR 0006](docs/decisions/0006-single-public-repository-and-app.md), and the [release checklist](docs/operations/release-checklist.md).
