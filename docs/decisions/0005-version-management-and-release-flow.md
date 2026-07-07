# Decision 0005: Version Management And Release Flow

Date: 2026-07-07

## Decision

Quota Capsule uses one durable release mechanism:

```text
private development branch -> Dev Local app -> Beta app -> public staging -> public main -> beta tag / release
```

This project keeps three product channels and two repository surfaces:

| Layer | Purpose | User-visible artifact |
| --- | --- | --- |
| Development | Daily private work, bug fixing, owner validation | `Quota Capsule Dev Local.app` |
| Public Beta | Public GitHub users and invited testers | `Quota Capsule Beta.app` |
| Stable | Later signed, notarized release | `Quota Capsule.app` |

| Repository surface | Role |
| --- | --- |
| Private working repository | Implementation source of truth, internal planning, release preparation |
| Public repository | Distribution source of truth, public issues, public install instructions |

The public repository is:

```text
https://github.com/Bono12138/codex-quota-capsule
```

## Non-Negotiable Rules

1. All changes start in the private working tree.
2. Do not hand-patch the public sync worktree as the first fix.
3. Do not patch only an already-built `.app`.
4. Do not use local `main` casually; feature and bug work should use `codex/*` branches.
5. P0/P1 bugs take priority over new features and polish.
6. Public beta builds must route user issues to the public repository.
7. Development builds must not default to the public issue tracker.
8. Public staging must pass the audit before anything is copied to the public repository.
9. Private handoff files, private strategy notes, local state, credentials, auth files, prompts, session text, tokens, cookies, and raw credentialed diagnostics must not enter public staging.
10. Current-release copy must describe shipped behavior only. Future analytics, token tracking, or provider comparisons belong in planning docs until implemented and released.

## Branch Rules

### Private Working Tree

Use `codex/*` branches for normal work.

Examples:

```text
codex/p0-stability-i18n
codex/beta-0.1-stabilization
codex/token-usage-research
```

Recommended meanings:

- `codex/p0-*`: urgent blocker or stability work.
- `codex/beta-*`: beta stabilization work.
- `codex/feature-*`: planned feature work.
- `codex/docs-*`: documentation-only work.

Local `main` may be stale or diverged. Before using it, inspect:

```text
git status --short --branch
git branch -vv
git log --oneline --decorate -5
```

### Public Repository

Public `main` should represent the latest public beta source that a user can install from GitHub.

Do not make first edits in `artifacts/public-repo-sync`. That directory is only a temporary public mirror worktree used after private validation and public staging audit.

## App Channel Rules

| Channel | App | Bundle ID | Process | Data directory | Feedback target |
| --- | --- | --- | --- | --- | --- |
| Development | `Quota Capsule Dev Local.app` | `com.bono.quota-capsule.dev` | `QuotaCapsuleDevLocal` | `~/Library/Application Support/Quota Capsule Dev Local` | `QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL`, otherwise email fallback |
| Public Beta | `Quota Capsule Beta.app` | `com.bono.quota-capsule.beta` | `QuotaCapsuleBeta` | `~/Library/Application Support/Quota Capsule Beta` | public GitHub Issues |

Build commands:

```text
npm run mac:run:dev
npm run mac:run:internal-test
npm run mac:package:dev
npm run mac:package:internal-test
```

Shared app behavior changes require both app channels to be rebuilt before release.

## Version Numbering

Use public labels like:

```text
v0.1.0-beta.1
v0.1.0-beta.2
v0.2.0-beta.1
v0.2.0
```

Rules:

- P0/P1 bugfix after a public beta increments the beta number.
- A group of user-facing features increments the minor version and resets beta number to `beta.1`.
- Stable release removes the beta suffix.
- `CFBundleShortVersionString` is numeric, for example `0.1.0`.
- `CFBundleVersion` is a monotonically increasing build number.
- `package.json` should either match the active release line or clearly remain private build tooling. Do not let release copy, tags, app metadata, and package metadata tell conflicting stories.

## Change Flow By Type

### P0/P1 Bug

1. Fix in private working tree.
2. Run focused tests.
3. Build and validate `Quota Capsule Dev Local.app`.
4. Ask owner to manually judge mouse-heavy or visual hand-feel only when needed.
5. Build and validate `Quota Capsule Beta.app`.
6. Run public staging.
7. Review the audit.
8. Sync to public repository.
9. Push public `main`.
10. Confirm GitHub Actions.
11. Tag a new beta if the fix changes the public tester build.

### UI Or Feature Change

1. Decide whether the change belongs in the current beta.
2. Implement in private working tree.
3. Validate Dev Local first.
4. If accepted for current beta, rebuild Beta and follow public staging.
5. If not accepted for current beta, keep it off public `main`.

### Public Documentation Or Issue Template Change

1. Edit in private working tree.
2. Run public staging.
3. Review public staging audit.
4. Sync to public repository.

Even documentation-only public changes should not be hand-edited only in the public mirror, because that causes private and public copies to drift.

## Release Candidate Gate

Before declaring a beta release candidate, complete this checklist:

1. Confirm current branch and dirty state.
2. Confirm no P0/P1 blockers remain in `docs/product/bug-triage-and-release-blockers.md` or public GitHub Issues.
3. Confirm current release scope in `docs/product/development-plan.md`.
4. Confirm release checklist in `docs/product/release-checklist.md`.
5. Run:

```text
npm test
npm run mac:spec
swift build --product QuotaCapsuleMac
```

6. Build and verify both channels if shared app code changed:

```text
npm run mac:package:dev
npm run mac:package:internal-test
codesign --verify --deep --strict --verbose=2 "dist/development/Quota Capsule Dev Local.app"
codesign --verify --deep --strict --verbose=2 "dist/internal-test/Quota Capsule Beta.app"
```

7. Confirm development and beta app routing:

- app name
- bundle ID
- process name
- data directory
- GitHub Issues target
- analytics endpoint
- channel label

8. Run public staging:

```text
npm run public:prepare
```

9. Review:

```text
artifacts/public-repo-staging/PUBLIC_STAGING_AUDIT.md
```

10. Sync reviewed staging to `artifacts/public-repo-sync`.
11. Run tests from `artifacts/public-repo-sync`.
12. Commit and push public `main`.
13. Confirm GitHub Actions.
14. Create or update the beta tag / release label.

## Public Sync Commands

Use this shape after private validation:

```text
npm run public:prepare
rsync -a --delete --exclude='.git' --exclude='PUBLIC_STAGING_AUDIT.md' artifacts/public-repo-staging/ artifacts/public-repo-sync/
```

Then validate inside `artifacts/public-repo-sync` before committing public changes.

## What Codex Should Do By Default

When the owner reports a bug:

1. Classify severity first.
2. Fix P0/P1 before features.
3. Apply the fix to the private working tree.
4. Rebuild Dev Local first.
5. Rebuild Beta only after Dev Local is plausible.
6. Sync public only after local validation.

When the owner asks whether the product is ready to publish:

1. Inspect branch and dirty state.
2. Inspect public sync state.
3. Inspect release checklist and blocker docs.
4. Run the release candidate gate.
5. Report any remaining blockers clearly.

When the owner asks for new features near a release:

1. Decide whether it is a blocker, current-beta scope, or next-version scope.
2. Avoid expanding the release if stability risk is higher than release value.
3. Record accepted, deferred, and rejected decisions in product docs.

## Current Known Cleanup Need

As of this decision, the mechanism exists but needs continued discipline:

- The private working tree may contain many uncommitted release-line changes.
- Local `main` may not match public `origin/main`.
- Version metadata should be aligned before the next public tag.
- Public beta copy should stay local-first unless analytics or token-history features are actually shipped.
