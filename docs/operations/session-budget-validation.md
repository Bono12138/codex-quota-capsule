# Session-budget validation record

Date: 2026-09-20
Source version: 0.5.0 development

Follow-up: the default budget now starts automatically (daily 09:00–23:00, zero reserve), weekly progress is restored, and custom schedules remain optional. The updated installed app was checked with no saved custom plan. Default activation, overnight deadline fallback, restart, custom-plan preservation and quota-track rendering are covered by 142 Swift tests. The earlier confirmation-only onboarding below describes the initial implementation and is superseded.

## Automated checks

- 140 Swift tests, including allocation conservation, idle freeze, restarts, reserves, DST, overnight schedules, deadline freshness and five-hour priority.
- 131 TypeScript tests for the retained browser/source/forecast layers.
- Node build/lint, Swift core specification, repository policy and quota-surface audits.
- Installed release-mode app passed the binary privacy audit.
- Synthetic native summary renders inspected in English, Simplified Chinese and Traditional Chinese at the narrow layout. Light/dark state sheets cover setup, unavailable, reserve, no-session and overspent scenarios.

## Native interaction

Observed the installed app reading live quota, opening its plan editor, saving a temporary plan, retaining that allocation across a rebuild/restart, scrolling the detail panel, and changing languages. The exact deadline appears above the budget card. Live screenshots are kept outside the repository because they contain account-specific information.

The editor's initial example requires an explicit save. Temporary validation settings are removed before handoff; the user's schedule remains unconfirmed.

## Limits and release gate

This is implementation verification, not evidence of reduced waste or improved user behavior. No causal estimate is made from historical consumption. No live credit was redeemed for testing.

Synthetic text rendering does not exercise AppKit controls. The editor is checked in the running native app; ImageRenderer output of native controls is not accepted as UI evidence.

Full three-language, all-state, all-width and busy-background visual coverage, VoiceOver testing, and a prospective real work cycle remain outstanding. Source may be reviewed and merged with these limits documented. A new downloadable beta requires completion of the [release checklist](release-checklist.md); the existing release remains unchanged meanwhile.
