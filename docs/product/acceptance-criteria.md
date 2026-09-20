# Acceptance criteria

Updated: 2026-09-20

## Budget behavior

- A fresh install produces a budget on its first valid reading, using the daily 09:00–23:00 default with zero reserve.
- Preserve saved custom schedules. Restoring defaults is explicit and persists across restarts.
- Default mode uses remaining time when no daytime session precedes the deadline.
- Only planned time before the earliest known eligible deadline receives allocation.
- Allocations sum to the spendable balance; reserve never creates negative allowances.
- Idling or slowing consumption during a session does not enlarge its fixed allocation.
- Account deltas subtract across devices; missing intervals are not labeled as sleep.
- Unused quota can be redistributed next session; restart alone cannot reallocate.
- Explicit edits, reset/endpoint changes and time-zone changes re-evaluate allocation.
- Overnight weekdays, full days, DST, no remaining sessions and invalid data are tested.
- Expiry alone cannot create replenishment. New-session and deadline boundaries require fresh readings.
- Five-hour exhaustion is clear even if weekly allowance remains.

## User interface

- Compact and expanded surfaces show the exact next deadline.
- Expanded reading order starts with deadline and immediate quota limits.
- Customization is optional and secondary; the default schedule is labelled as a product default.
- The weekly-used progress bar remains visible without opening settings; real five-hour progress stays separate.
- Allocation, actual weekly remaining and five-hour use are clearly distinguished.
- Chinese and English text is readable at supported widths, with meaningful line breaks.
- Keyboard focus, editing, cancel/save, expansion and language switching are checked in the native app.
- Light/dark screenshots cover setup, active, upcoming, spent, reserved, no-session and unavailable states.
- Missing or stale data never carries a new green assurance.

## Engineering and privacy

Run Node tests/build/lint, Swift tests/core spec, repository/quota-surface audits, and release-artifact privacy scan. Render tests use synthetic values. Preserve the existing history and authentication state. Verify one installed app, signing, version and commit identity.

Plan and anchor data remain local. No private user-home path, database, raw authenticated response or personal usage measurement belongs in a public commit.

## Evidence required for release

Automated tests do not prove live usability or reduced waste. Record actual UI checks and any untested states. Merge only after CI/review; build a public binary from the exact merged commit. Follow [the release checklist](../operations/release-checklist.md).
