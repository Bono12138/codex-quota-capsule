# Release Checklist

## Repository And Attribution

- [ ] Work starts from current public `main` on a `codex/*` branch.
- [ ] Every commit author/committer maps to the intended GitHub contributor.
- [ ] `main` protection requires pull requests, linear history, `node`, and `macos-swift` checks.
- [ ] The working tree is clean and merged branches are scheduled for deletion.

## Privacy And Documentation

- [ ] `npm run audit:repository` passes over all tracked files.
- [ ] No local database, raw authenticated response, secret, personal path, or private repository address is tracked.
- [ ] README, install guide, docs index, decisions, product contract, acceptance criteria, changelog, and release notes match shipped behavior.
- [ ] Analytics schema and consent boundary are unchanged or explicitly reviewed.

## Automated Verification

```bash
npm test
npm run build
npm run lint
npm run audit:repository
npm run audit:weekly-only
swift test
swift run QuotaCapsuleCoreSpec
swift build --product QuotaCapsuleMac
npm run mac:package
git diff --check
```

## App And UI Verification

- [ ] Package signature verifies with `codesign --verify --deep --strict`.
- [ ] Version, build, tag, release target, artifact checksum, and commit fingerprint agree.
- [ ] Deterministic screenshots cover every state in three languages and light/dark/busy backgrounds.
- [ ] Real interaction covers dragging, resizing, expanding, menu actions, links, long text, and stale/failure recovery.
- [ ] Spotlight finds one supported Quota Capsule app and one `QuotaCapsuleBeta` process runs from `/Applications`.
- [ ] A live read and read-only history query agree with visible percentages and timestamps.
- [ ] Real use or a meaningful idle interval changes the forecast as expected before completion is claimed.

## Publication

- [ ] Pull request review and CI pass.
- [ ] Release artifact is built from the exact merged `main` commit.
- [ ] Release is marked prerelease for `vMAJOR.MINOR.PATCH-beta.N`.
- [ ] Release notes state user-visible changes, known limits, migration notes, and verification evidence.
- [ ] Remote feature branch and disposable worktree are removed after merge and recovery checks.
