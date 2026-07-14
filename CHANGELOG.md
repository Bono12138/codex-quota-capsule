# Changelog

All notable user-visible and repository-governance changes are recorded here.

## Unreleased

## 0.3.1-beta.1 — 2026-07-14

### Changed

- Make weekly pace evidence invariant to duplicate and flat polling frequency by measuring each clean monotonic segment once.
- Fuse three or more independent pace estimates with a median/MAD consensus, while retaining conservative one- and two-source behavior and lowering confidence when sources disagree across the decision boundary.
- Replace normalized daily-rate jargon on the main surface with the actual observed duration and allowance change.
- Explain cross-zero reset projections honestly instead of clamping negative outcomes into a misleading `0%–Y%` range.
- Treat reset-credit count, nullable/capped details, and weekly pace as separate facts so credits never create false safety.

### Added

- Show every returned available reset credit at the bottom of the expanded panel, sorted by local expiry time and displayed through the minute.
- Keep privacy-safe local reset-credit history with SHA-256 identity fingerprints, provider timestamps, coalesced bank runs, and conservative expired/likely-redeemed/unknown lifecycle labels.

### Fixed

- Keep the status menu and language submenu stable while open by applying immutable presentation snapshots and deferring the latest background update until menu tracking ends.
- Add shared Swift/TypeScript polling-equivalence fixtures so sparse and dense observations of the same real change cannot silently diverge again.

## 0.3.0-beta.1 — 2026-07-13

### Changed

- Adopt one public repository and one Beta application identity.
- Replace the copied release mirror with an in-place tracked-tree repository audit.
- Add archive-before-delete retirement controls for the former secondary app workflow.
- Replace the elapsed-time gate with immediate first-reading estimates and adaptive cycle, recent, activity, and historical evidence.
- Model coarse percentages as ±0.5-point intervals and preserve estimator disagreement in the forecast range.
- Calculate the next-24-hour budget from all remaining allowance and time to reset, with no hidden arbitrary buffer.
- Separate weekly quota reset, last successful data read, and next automatic read in the interface.
- Put the next-24-hour budget before recent usage and explain forecast confidence in plain language.

### Added

- Cross-runtime pace-evidence tests and expanded shared Weekly Only fixtures.
- A maintained forecast methodology with equations, confidence rules, stale behavior, limits, and change control.

### Fixed

- Correct the repository-local Git identity to `Bono12138` and remove the erroneous co-author attribution from reachable default-branch history.
- Keep unconfirmed reset/correction candidates from replacing the last accepted displayed window, and expose a neutral confirmation state without relabelling old data as a fresh success.
- Propagate activity-rate uncertainty through the endpoints of each continuous quantized increase run without double-counting shared middle readings.
- Run repository metadata audits automatically for version-tag pushes as well as pull requests and `main`.
- Show “no usage observed” after a fresh zero reading instead of converting quantization uncertainty into a fast-pace warning.
- Hide pace comparison and forecast trend details while the live snapshot is stale.
- Align reset terminology in the Swift and TypeScript interfaces.
- Recompute and verify checksums after retired Dev artifacts enter the local archive.

## 0.2.0-beta.1 — 2026-07-13

- Pivot the product to a Weekly Only runway and next-24-hour budget surface.
- Add cleaned weekly history, forecast ranges, stale-data protection, and Swift/TypeScript fixture parity.
