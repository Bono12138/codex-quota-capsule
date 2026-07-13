# Decision 0006: Single Public Repository And Single App

Date: 2026-07-13
Status: Accepted
Supersedes: Decision 0004 and Decision 0005

## Context

The previous workflow separated a working tree from a copied public distribution tree and installed two app identities. It increased documentation drift and allowed two capsules to run simultaneously. A mistaken local Git identity also reached a squash-merge co-author footer.

## Decision

`Bono12138/codex-quota-capsule` is the only source of truth. Development uses short-lived `codex/*` branches, public pull requests, required CI, and squash/rebase merge into protected `main`.

During beta there is one installed identity: `Quota Capsule Beta.app`, bundle `com.bono.quota-capsule.beta`, process `QuotaCapsuleBeta`, and the Beta application-support directory. Tests and previews may run from a branch, but no persistent second app channel is installed.

The release audit scans every tracked file in place. It replaces copied allowlist staging and blocks credentials, personal paths, runtime output, obsolete channel identifiers, and documentation drift.

## Consequences

- Product decisions, specifications, tests, source, and release history are reviewable by contributors.
- Private raw context is distilled into public decisions and archived locally.
- Every release verifies commit attribution, branch protection, privacy, test evidence, app identity, signature, installed path, and live behavior.
- Merged branches and disposable worktrees are removed after archival/provenance checks.
- A future stable rename must migrate the same app identity deliberately; it must not reintroduce coexisting channels.
