# Product Strategy And Commercialization

Date: 2026-07-01

## Product Thesis

Quota Capsule is not primarily a quota viewer.

It is a quota runway assistant for AI coding work:

> It tells the user whether the current usage pace can survive until the next reset.

The product should make quota feel like battery/range, not like an accounting number.

## Target User

Initial user:

- Heavy Codex user.
- Runs long coding sessions or multiple agent tasks.
- Does not want to open dashboards.
- Wants to know whether to keep working, slow down, or stop launching large tasks.

Secondary future user:

- Users of other agent products with rate windows.
- Developers who want a small adapter-friendly quota surface for their own tool.
- Teams that want shared internal conventions for AI usage pacing, but not surveillance.

## Product Shape

### Route 1: Chrome Independent Version

This should be built first as an independent version.

Why:

- It can be developed on Mac while reaching Windows and Linux users through Chrome.
- It tests whether browser-based distribution is enough before investing in native Windows.
- It gives the project a lightweight public artifact quickly.

Constraints:

- Browser extensions cannot automatically access arbitrary local Codex state without permission, page parsing, a native helper, or a safe bridge.
- The first Chrome version should be mock/source-abstracted until data-source feasibility is proven.
- It should not pretend to be a full Codex desktop integration until that path is technically verified.

Likely Chrome surfaces:

- Toolbar popup: quick status and settings.
- Optional page overlay or pinned mini badge: the "always visible" version.
- Extension options page: source setup, privacy explanation, display mode.

### Route 2: Mac Local Version

This is important because the founder/user wants to use it daily and make social content from the real experience.

Default display mode:

- Floating desktop capsule.

Optional display mode:

- Menu bar item.

Why both:

- The floating capsule solves the "I am too lazy to click" problem.
- The menu bar is socially accepted on macOS and gives users a less intrusive fallback.

### Route 3: Windows Native Version

This should stay later.

Why:

- QuotaGem already covers the Windows tray direction strongly.
- Building a polished native Windows product has packaging, notification, autostart, and trust costs.
- The better sequence is Chrome first, Mac local for founder-led content, then Windows native if demand is proven.

## Experience Model

Default capsule should answer one question:

> Can I keep going at this pace?

Primary states:

| State | Meaning | Example Copy |
| --- | --- | --- |
| Safe | Current pace can survive reset with meaningful margin. | `Safe · enough until 14:00` |
| Watch | Can survive reset, but margin is thin or weekly pressure is rising. | `Watch · enough, but little margin` |
| Danger | Current pace will run out before reset. | `Danger · empty around 13:00` |
| Unknown | Data is missing, stale, or unreliable. | `Unknown · quota data unavailable` |

Expanded detail should explain:

- Time progress.
- Quota used.
- Current burn rate.
- Reset time.
- Estimated empty time if unsafe.
- Projected remaining at reset if safe.
- Weekly pressure only when relevant.

## Design Principles

1. Default to ambient, not dashboard.
2. Prefer one human judgment over four numbers.
3. Use color sparingly and consistently.
4. Show unknown honestly.
5. Do not hide why the verdict was made.
6. Avoid account/session management in MVP.
7. Make the product good-looking enough that users are willing to leave it visible all day.

## Competitor Lessons

### From QuotaGem

Useful:

- Windows tray distribution makes sense.
- Compact and expanded modes are a good interaction pattern.
- Circular usage rings are glanceable.
- Theme, scale, threshold, and notification settings matter.
- `codex app-server` plus JSON-RPC is a practical source path.

Do not copy:

- Multi-provider dashboard density as the default state.
- Threshold-first warning as the primary product idea.
- Windows-native scope before demand is clearer.

### From ClaudeBar

Useful:

- Quota apps can look like polished consumer tools.
- Menu-bar presence is acceptable for daily monitoring.
- Pace-aware logic is a real differentiator.
- Themes can become a retention and delight feature.

Do not copy:

- Heavy gradient dashboard as the default product state.
- Broad provider monitor positioning before Codex-first quality is excellent.

### From Codex Quota Viewer

Useful:

- Native Codex integration has user value.
- Stale/read-failure states are important.
- A Mac app can bundle useful local tooling.

Do not copy:

- Account vault.
- Auth switching.
- Session manager.
- Config mutation as a first product promise.

### From codex-quota

Useful:

- Terminal-first users value fast keyboard workflows.
- Mock/demo modes make trial safer.

Do not copy:

- TUI as a mainstream visual direction.
- Account switching as core scope.

### From opencode-quota

Useful:

- Quota works best when it appears where work happens.
- Multiple surfaces can share the same data layer: sidebar, toast, status line, command.
- CLI output and JSON output are useful for integrations.

Do not copy:

- Tool-ecosystem lock-in as the whole product.
- Config-heavy onboarding for non-technical users.

## Commercialization Lessons

The reviewed projects mostly teach distribution and trust more than direct monetization.

Observed distribution patterns:

- QuotaGem: Windows portable release.
- ClaudeBar: DMG, ZIP, Homebrew cask, signed/notarized release.
- Codex Quota Viewer: packaged macOS app.
- codex-quota: Homebrew and Go install.
- opencode-quota: `npx` installer and npm package.

Implications for Quota Capsule:

- Open source is the right starting posture.
- Installation friction matters as much as feature count.
- Trust is central because the product touches local AI-tool state.
- The project should explain exactly what it reads and what it never writes.
- A clean uninstall story is part of product quality.

Recommended commercialization path:

1. Open-source core and basic apps.
2. Build reputation through transparency, source adapters, and visible product polish.
3. Grow through founder-led content showing real use during Codex work.
4. Add optional paid surfaces only after retention is proven.

Possible future paid surfaces:

- Team policy pack: shared defaults, thresholds, and documentation for teams.
- Cross-device sync of display preferences, not raw usage unless explicitly opted in.
- Advanced history and export for personal workflow analysis.
- Priority packaged builds and auto-update channel.
- Custom adapter support for companies using internal agent tools.

Avoid early monetization around:

- Locking the basic quota verdict behind payment.
- Uploading private usage data by default.
- Selling account/session management before the product has earned trust.
- Presenting team features in a surveillance-like way.

## Positioning

Public English:

> A tiny quota runway capsule for Codex. It tells you whether your current burn rate can survive until reset.

Public Chinese:

> 一个 Codex 额度续航小胶囊：不用心算，直接告诉你现在能不能继续干活。

Developer/open-source:

> Codex-first, adapter-friendly quota pacing UI for AI agents.

## MVP Recommendation

Build the next MVP around these workstreams:

1. Read-only Codex app-server source.
2. Shared runway engine in `packages/core`.
3. Chrome independent mock-first extension.
4. Mac floating capsule mock/prototype.
5. Product-quality visual pass before public launch.

Success criteria:

- A user can understand status in under one second.
- Unknown source state never looks safe.
- The product can explain its verdict when clicked.
- The UI looks good enough to keep visible during real work.
- The repo clearly separates public source from local private state.

