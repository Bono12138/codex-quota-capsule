# Legacy Development Workflow Retirement

Date: 2026-07-13
Status: In progress

## Scope

The former split-repository workflow and secondary local application identity are being retired in favor of Decision 0006. This public record excludes private document contents, local database contents, usernames, and absolute local paths.

## Preservation

Before cleanup, the maintainer created an external dated archive containing a full Git bundle, private-only strategy and research source files, local legacy application history, a manifest, and SHA-256 checksums.

After legacy application or data files are moved, the retirement helper regenerates `SHA256SUMS` over the final archive contents and verifies the new list. This prevents moved runtime state from sitting outside the recovery proof.

The first restoration test discovered that the source checkout was shallow. The repository was unshallowed, the bundle rebuilt, and a fresh clone plus `git fsck --full` passed. This failure is preserved because it demonstrates why `git bundle verify` alone is not sufficient.

## Public Distillation

Still-valid conclusions retained publicly include:

- the product answers a runway decision rather than displaying a bare percentage;
- local-first privacy and explicit analytics consent;
- tri-language UI and cross-language layout review;
- no default ring chart or user threshold burden;
- Codex-assisted installation and public Issues feedback;
- automated tests plus mandatory real UI/interaction acceptance.

## Completion Criteria

- [ ] Single repository and single-app changes are merged.
- [ ] Old remote branches are deleted after bundle containment checks.
- [ ] Legacy local data is moved into the verified archive.
- [ ] Old worktrees, generated staging output, and obsolete branches are removed.
- [ ] A fresh clone of public `main` passes the complete release suite.
