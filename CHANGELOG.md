# Changelog

All notable user-visible and repository-governance changes are recorded here.

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

## 0.2.0-beta.1 — 2026-07-13

- Pivot the product to a Weekly Only runway and next-24-hour budget surface.
- Add cleaned weekly history, forecast ranges, stale-data protection, and Swift/TypeScript fixture parity.
