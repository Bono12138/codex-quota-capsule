# Quota Capsule Single Public Repository And Adaptive Weekly Forecast

Date: 2026-07-13
Target release: `v0.3.0-beta.1`
Status: Product and repository direction approved; written specification awaiting owner review
Supersedes: repository/channel sections of ADR 0004, ADR 0005, and the fixed six-hour calibration rule in the Weekly Only design

## 1. Executive Decision

Quota Capsule will use one public GitHub repository as its only source of truth:

- <https://github.com/Bono12138/codex-quota-capsule>

Development happens on short-lived branches in that repository and reaches `main` only through reviewed pull requests. The private-working-tree/public-staging split, the Dev Local app channel, and the copy-based public staging workflow will be retired.

The installed product will also have one identity. During the current beta, that identity is `Quota Capsule Beta.app`. Local development may run tests, previews, and an unpackaged debug executable, but it must not install a second persistent capsule with a different bundle identifier or data directory.

The product remains Weekly Only. Its primary value is an early, honest answer to:

> At the user's observed pace, is the remaining weekly Codex allowance likely to last until reset, and how much can they use over the next 24 hours while staying on budget?

The fixed requirement to collect six hours of history before showing value is removed. Forecasts will begin with the first valid weekly reading and become narrower as evidence accumulates. Confidence reflects evidence quality; it is not a timer.

## 2. What The Audit Found

### 2.1 There is no second GitHub quota repository

The GitHub account has one Quota Capsule repository. The perceived “Dev repository” is a combination of:

- a `Quota Capsule Dev Local.app` release channel;
- separate development bundle, process, and data-directory identities;
- old local worktrees and branches;
- documentation that describes a private working tree and copied public staging tree;
- scripts and environment variables dedicated to the Dev channel.

This structure directly caused the two-capsule failure: Dev Local and Beta were allowed to run simultaneously.

### 2.2 The public `main` branch already contains the current Weekly Only release

Public `main` points to merge commit `8457112`, released as `v0.2.0-beta.1`. The old Weekly Only implementation branch was squash-merged, so its commits are not ancestors of `main`, but its released content is already represented on `main`.

Old branches still contain useful design history and some documents intentionally excluded from the current public tree. Those records must be reviewed and archived before branch deletion; they must not continue to act as a parallel source of truth.

### 2.3 The current six-hour gate is not evidence based

The installed Beta database already contained almost five hours of current-cycle history, 248 current-reset-cluster samples, and multiple real percentage transitions. The UI still said it needed six hours before making a judgment. This proves the gate measures wall-clock waiting rather than forecast evidence.

## 3. Repository Model

### 3.1 One source of truth

The public repository is authoritative for:

- source code;
- tests and fixtures;
- product specifications and architectural decisions;
- public-safe research conclusions;
- build and release scripts;
- release notes and changelog;
- issue and contribution workflows.

No second clone, worktree, staging directory, generated app, or local document is allowed to become an alternative authoritative version.

Local worktrees may be used temporarily for isolation. They must be registered by Git, ignored from the working tree, named for a specific branch, and removed after merge. They are disposable execution environments, not repositories.

### 3.2 Branch and pull-request flow

```text
public main
  -> codex/<short-feature-name>
  -> tests + repository audit + app verification
  -> pull request
  -> required CI and release review
  -> squash merge to public main
  -> signed/tagged beta release
```

Rules:

1. `main` is protected from direct routine pushes, force pushes, and deletion.
2. Every product change includes tests and user-facing documentation in the same pull request.
3. Branches are deleted locally and remotely after merge.
4. Release artifacts are built from the exact reviewed `main` commit.
5. The installed app must expose the version and short commit fingerprint used to build it.
6. Urgent fixes still use a branch and pull request; urgency changes review speed, not provenance.

### 3.3 Public-safe documentation policy

Specifications, plans, ADRs, forecast methodology, acceptance criteria, and release retrospectives stay public when they are useful to contributors and contain no private data.

The repository must not contain:

- tokens, cookies, sessions, credentials, certificates, or authenticated raw responses;
- local usernames, absolute personal paths, private repository URLs, prompt/session text, or window titles;
- raw local databases, logs, crash dumps, or unredacted diagnostics;
- private commercial notes, personal handoff prompts, or third-party assets without a clear redistribution right.

Useful conclusions from private notes should be rewritten as public product decisions. Raw private context should be archived locally outside the Git repository.

### 3.4 Legacy archive and retirement sequence

Destructive cleanup is allowed only after this sequence succeeds:

1. Enumerate every local and remote legacy branch, tag, worktree, generated app, distribution directory, and private-only document.
2. Create a dated archive outside the public repository at:
   `~/Documents/Quota Capsule Archive/2026-07-13-dev-retirement/`.
3. Export private-only documents and relevant research assets into the archive without changing their contents.
4. Create a full Git bundle containing all legacy refs needed for forensic recovery.
5. Write an archive manifest containing source ref, destination, size, SHA-256, privacy classification, and the public-safe document that preserves any useful conclusion.
6. Verify every archived checksum and prove the Git bundle can be listed and cloned.
7. Distill useful public-safe decisions into the public repository.
8. Run a tracked-file secret/privacy audit over the public branch.
9. Delete obsolete remote branches, local branches, linked worktrees, Dev app bundles, Dev processes, Dev data directories, generated staging/sync directories, and obsolete scripts.
10. Make a fresh clone of public `main` at the canonical Desktop path and run the full test and build suite.
11. Delete the retired local repository only after the fresh clone and archive both pass verification.

Deleting remote branches does not guarantee immediate deletion of unreachable Git objects. If the audit finds a real secret in published history, branch deletion is insufficient: revoke/rotate the secret first, then use a coordinated history rewrite and GitHub cache/support process. Product strategy text is not treated as a credential, but still receives the local-archive/public-distillation treatment.

## 4. One App Identity

### 4.1 Current beta identity

- App: `Quota Capsule Beta.app`
- Executable: `QuotaCapsuleBeta`
- Bundle identifier: the current public Beta identifier
- Data directory: `~/Library/Application Support/Quota Capsule Beta`

The Development channel enum/case, Dev bundle name, Dev executable, Dev bundle identifier, Dev data directory, Dev-only feedback route, Dev-only analytics variables, and `mac:*:dev` package commands will be removed.

Development verification uses:

- unit and integration tests;
- deterministic SwiftUI mock states or previews;
- an unpackaged debug executable when needed;
- a locally packaged Beta built from the branch only after automated checks pass.

### 4.2 Single-instance acceptance

Every install or update must verify:

- exactly one Quota Capsule application is indexed by Spotlight in supported install locations;
- exactly one Quota Capsule process is running;
- no Dev Local process or application remains;
- the running executable path is inside `/Applications/Quota Capsule Beta.app`;
- the UI version and commit fingerprint match the release candidate.

The installer should terminate known legacy process names and offer safe cleanup of legacy application/data locations. It must not delete user history until migration or archival is proven.

## 5. Forecast Evidence Model

### 5.1 Inputs

Each valid weekly reading contributes:

```text
WeeklyObservation
- fetchedAt
- usedPercentInterval
- remainingPercentInterval
- canonicalResetAt
- cycleStartAt
- cycleID
- qualityFlags
```

Because the upstream percentage is quantized, a reported integer `p` is modeled as an interval around `p`, clipped to `[0, 100]`, rather than as an exact continuous value. Forecast math propagates this uncertainty instead of pretending each point is exact.

### 5.2 Quality before pace

The quality engine must:

- validate range, complement consistency, timestamps, and weekly duration;
- confirm reset changes across three consecutive live reads before opening a new cycle;
- group observations by canonical reset cluster;
- suppress stale or conflicting samples from new pace conclusions;
- tolerate small downward corrections without interpreting them as negative consumption;
- retain raw observations for diagnostics while forecasting only from cleaned observations.

### 5.3 Evidence extractors

The predictor derives independent pace evidence rather than one coarse slope.

#### Cycle pace

Use the known cycle start (`resetAt - weeklyDuration`) and current used interval to estimate average consumption over elapsed cycle time. This is available from the first valid reading and gives an intentionally wide preliminary band.

#### Recent pace

For cleaned observations in the recent horizon, estimate bounded consumption change over real elapsed time. Use robust pairwise slopes or an equivalent outlier-resistant estimator. Flat time is retained because idle periods are part of the user's actual weekly pace.

#### Transition evidence

Extract genuine upward percentage transitions and their timing. Transitions provide stronger evidence than repeated flat samples. Downward corrections and reset candidates do not count as consumption events.

#### Activity segments

Split history into active bursts, ordinary use, and idle gaps using transitions and observation gaps. Estimate:

- active consumption rate;
- recent active-duty ratio;
- decayed recent average that naturally slows during a long idle period.

The activity model explains bursty behavior but cannot by itself override the full-cycle budget evidence.

#### Historical-cycle prior

After complete cycles exist, use robust summaries of comparable completed cycles as a weak prior. Current-cycle evidence always receives more weight. No prior is required for first-run value.

### 5.4 Adaptive fusion

Each estimator returns a pace interval and reliability score. Reliability depends on:

- elapsed cycle coverage;
- number and spread of distinct upward transitions;
- observation freshness;
- reset stability;
- agreement between estimators;
- amount of recent active and idle evidence;
- presence of data-quality flags.

The final pace band is a reliability-weighted robust fusion. A weighted median or clipped weighted quantile is preferred over an ordinary mean so one burst or malformed sample cannot dominate.

There is no `minimumCoverage = 6 hours` product rule. Time only matters through the evidence it creates. A single valid reading yields a low-confidence preliminary cycle estimate; additional transitions and coverage increase confidence and narrow the interval.

### 5.5 Budget and outcome math

Let:

- `R` be the current remaining-percentage interval;
- `T` be hours until reset;
- `P` be the fused usage pace interval in percentage points per hour.

Then:

- sustainable pace is `R / T`;
- projected additional use is `P * T`;
- projected remaining at reset is `R - P * T`;
- next-24-hour budget is `R / T * min(24, T)`.

The next-24-hour budget is rounded down for display. It has no hidden arbitrary five-percent reserve. Measurement and model uncertainty are already represented by intervals and confidence.

Classification:

- `够用 / On track`: the conservative projected-remaining bound stays above zero;
- `偏快 / Running fast`: the forecast band overlaps zero or recent pace is materially above sustainable pace;
- `可能不够 / May run out`: even the optimistic projected-remaining bound is below zero;
- `刚开始 / Early estimate`: a valid preliminary estimate exists but evidence is sparse;
- `已用尽 / Exhausted`: current remaining allowance is effectively zero;
- `数据暂不可用 / Data unavailable`: source/reset/quality evidence is not valid enough for any honest estimate.

`正在校准` is not a mandatory waiting room. It may appear as supporting confidence language, but the primary surface should still show the best honest preliminary range whenever one can be computed.

### 5.6 Confidence

Confidence is `低 / 中 / 高`, derived from evidence and agreement. It must be accompanied by a short reason such as:

- `初步判断：只有当前周期平均速度`;
- `可信度中：已观察到 4 次实际增长`;
- `可信度高：周期、最近 24 小时和活动节奏一致`;
- `暂不判断：数据已过期`.

Confidence must never increase merely because the app remained open while receiving repeated identical samples.

## 6. User Interface

### 6.1 Collapsed capsule

Show only:

- outcome state;
- weekly used percentage;
- one short reason;
- time progress and usage progress;
- reset countdown when space permits.

Do not show source internals, 5-hour concepts, release channels, or a generic “calibrating for six hours” message.

### 6.2 Expanded capsule

Information hierarchy:

1. outcome and one-sentence explanation;
2. weekly time versus usage progress;
3. next-24-hour budget;
4. forecast range at reset and confidence reason;
5. recent 24-hour pace, cycle-average pace, and sustainable pace;
6. compact trend chart with an uncertainty band;
7. weekly reset date/time plus countdown;
8. data freshness: last successful read and next automatic attempt;
9. actions and collapsed diagnostics.

The normal UI should say, for example:

- `周额度将在 7月20日 08:11 重置（6天18小时后）`;
- `数据更新于 13:49:44，下次自动读取约 47 秒后`.

“刷新时间” must never ambiguously refer to both quota reset and data refresh.

### 6.3 Early-use behavior

- First valid nonzero reading: show an early cycle-based range immediately.
- First valid zero reading: show the remaining budget and `尚未观察到消耗`; do not invent a zero long-term pace.
- Burst followed by idle: recent pace decays through elapsed idle time instead of staying permanently high.
- Stale live read: preserve the last successful percentages but suppress new pace assurance and label the data age.
- Reset anomaly: keep the previous cycle until the three-read reset confirmation completes.

### 6.4 Accessibility and visual quality

- State is always expressed in text, not color alone.
- Primary text meets WCAG AA contrast against the translucent material in both light and dark desktop backgrounds.
- Dynamic type or equivalent macOS text scaling does not clip core status, budget, or reset information.
- Trend and progress visuals have textual equivalents.
- The collapsed and expanded windows must not overlap each other or leave a stale second panel.

## 7. Documentation System

The repository will use documents as maintained product infrastructure, not a one-time handoff dump.

Required changes:

- add an ADR for the single-public-repository and single-app decision;
- mark ADR 0004 and ADR 0005 as superseded without deleting their historical context;
- rewrite `AGENTS.md`, `CONTRIBUTING.md`, `INSTALL.md`, and all READMEs for the new flow;
- replace the public staging manifest with an in-place repository/release audit;
- add a public forecast-methodology document with equations, assumptions, and examples;
- update product brief, MVP scope, roadmap, visual direction, analytics, acceptance criteria, bug triage, and distribution docs;
- add a docs index that labels each document as current, historical, or superseded;
- add `CHANGELOG.md` and a release-retrospective template;
- record the legacy retirement archive location and checksums in a local manifest, while committing only a redacted retirement summary;
- update specifications and tests whenever a future algorithm or copy decision changes.

Documentation acceptance is part of release acceptance. A release is blocked when current code behavior contradicts current docs.

## 8. Release Audit Replacing Public Staging

`prepare-public-repo-manifest.ts` will be retired or converted into an in-place audit that scans all tracked files rather than copying an allowlist.

The release audit must fail on:

- credential-like filenames or secret patterns;
- absolute personal paths and private repository addresses;
- tracked build outputs, local databases, raw logs, or unapproved binaries;
- obsolete Dev-channel identifiers or commands;
- forbidden 5-hour product copy;
- version/tag/bundle mismatch;
- broken internal documentation links;
- missing test, changelog, acceptance, or release-review evidence.

The audit report should list paths and rule identifiers without printing secret values.

## 9. Test-Driven Acceptance Matrix

Implementation follows red-green-refactor. Every defect discovered during real use becomes a failing regression test before the fix.

### 9.1 Forecast tests

- first valid reading returns an early estimate without six-hour waiting;
- zero-use first reading avoids a false zero-pace conclusion;
- quantized 1% transitions produce bounded, not exact, rates;
- activity intervals propagate uncertainty from both quantized endpoints instead of widening only the summed delta;
- burst then idle decays recent pace;
- steady use produces a narrowing interval and rising confidence;
- conflicting cycle/recent estimators widen the interval and lower confidence;
- stale history suppresses current reassurance;
- reset jitter requires three-read confirmation;
- an unconfirmed reset/correction remains visibly pending while the last accepted timestamp and percentages stay unchanged;
- downward corrections do not become negative consumption;
- next-24-hour budget uses the actual time to reset;
- Swift and TypeScript fixtures remain identical.

### 9.2 Repository/channel tests

- no Development channel or Dev identifier remains in tracked product code;
- no public-staging/sync copy workflow remains;
- the audit scans the entire tracked tree;
- branch protection and required checks are documented and verified through GitHub;
- legacy archive checksums and Git bundle restoration pass;
- a clean clone can test, build, and package without hidden local files.

### 9.3 UI and installation tests

- collapsed and expanded states show reset countdown and distinct data-refresh time;
- preliminary, on-track, running-fast, may-run-out, exhausted, stale, unavailable, and reset-pending states render correctly;
- light/dark and busy desktop backgrounds remain readable;
- only one installed app and one process exist after update;
- the launched app path, version, commit, signature, live source, and stored history are verified;
- the owner performs a real-use observation pass after installation, not only a launch check.

## 10. Release Gates

`v0.3.0-beta.1` is releasable only when all of the following are true:

1. Legacy private-only material is archived and checksummed outside the repository.
2. Useful public-safe conclusions are merged into maintained public documents.
3. Obsolete remote branches, local branches/worktrees, Dev app/process/data, and generated staging directories are removed.
4. The canonical Desktop repository is a fresh clone of the public repository.
5. All TypeScript and Swift tests pass from a clean checkout.
6. The in-place privacy/release audit passes.
7. Forecast fixtures cover early, sparse, bursty, idle, stale, reset, correction, and conflict behavior.
8. UI review passes against deterministic mocks and a live weekly account.
9. Exactly one app and process are installed/running.
10. PR review, CI, version metadata, tag, release artifact, checksum, signature, installation, and commit fingerprint all agree.
11. README, installation guide, methodology, acceptance criteria, roadmap, ADRs, changelog, and release notes describe the shipped behavior.

## 11. Implementation Boundaries

This release does not add:

- any 5-hour display or fallback;
- token/prompt/project attribution;
- cloud sync or remote history storage;
- user-configurable prediction thresholds;
- predictive notifications;
- multiple installed release channels;
- a second repository or copied public staging tree.

Future capabilities must begin with a public specification and must preserve the one-source-of-truth rule.

## 12. Expected Result

After migration, contributors see one coherent public project, users see one application, and releases can be traced from a reviewed commit to the installed binary. The product produces useful weekly guidance immediately, labels uncertainty honestly, and gets more precise through observed transitions and time coverage instead of withholding value for an arbitrary six-hour period.
