# First-Level Language Menu Design

Date: 2026-07-14
Status: implemented and branch-validated; publication pending
Release target: `v0.3.2-beta.1`

## Problem

The floating panel currently hides language selection inside a button whose title follows the active interface language. A user who cannot read that language may not understand that the button contains language settings. The recent removal of the nested hover submenu fixed flicker but did not fix discoverability.

This is a release-blocking accessibility and onboarding defect. Language selection must remain understandable even when the current locale is wrong for the user.

## Approved Interaction

The panel action area contains four peer-level controls:

1. Refresh.
2. Feedback.
3. A language menu labeled with the universal globe symbol and `Language` in every locale. Chinese locales may append their translation, producing `Language / 语言` or `Language / 語言`.
4. More actions.

The language menu contains exactly three direct actions:

- `简体中文`
- `繁體中文`
- `English`

Each option is written in the language it activates. No language choice is nested inside More actions, and neither menu contains another menu.

More actions retains the status-menu, capsule visibility, guide, author, about/feedback, and quit commands. Language selection is removed from it so there is one obvious panel entry point and no duplicate hierarchy.

## Layout

The existing adaptive action layout remains responsible for width changes. At sufficient width, all four actions share one row. At narrower widths, the adaptive grid may wrap them into two rows. Labels remain single-line with minimum scaling, and the language control must not displace or truncate the core weekly decision content.

The language label always includes the English word `Language`; the globe icon is not the only cue. This supports users who do not recognize the current Chinese copy and users relying on text-based accessibility.

## State And Data Flow

Selecting an option continues to call `QuotaStore.selectLocale` with `.zhHans`, `.zhHant`, or `.en`. No persistence, analytics, quota source, refresh cadence, forecast, or reset-credit behavior changes.

Changing language may update the surrounding panel immediately after the menu action completes. The menu implementation must use two sibling, single-layer SwiftUI `Menu` controls so the previous parent-child hover path cannot return.

## Documentation Changes

Current feature copy, onboarding instructions, acceptance criteria, blocker rules, and release evidence must describe language as a first-level panel action. Historical documents remain historical and are not rewritten.

## Test-Driven Acceptance

Implementation starts with a failing source-architecture regression test that requires:

- two peer `Menu` controls inside `PanelQuickActionsView`;
- one explicit `languageMenu` used by `primaryActions`;
- the three locale actions inside `languageMenu`;
- no locale action inside `moreActionsMenu`;
- no nested `Menu` inside either menu implementation;
- a visible label using `store.copy.languageMenuTitle` and the globe symbol.

Swift copy tests must confirm that all three locale variants include `Language`. Existing TypeScript, Swift, Weekly Only, privacy, packaging, and signature gates remain mandatory.

Installed-app acceptance must verify all three interface languages:

1. The first-level globe/Language control is visible without opening More actions.
2. Its one-layer menu exposes all three language choices.
3. More actions no longer contains language choices.
4. Both menus remain open and selectable without flicker across a real automatic data-read interval.
5. The action area remains readable at normal and narrow supported capsule widths.

The release stays paused until these checks pass on an app installed from the exact merged `main` commit.
