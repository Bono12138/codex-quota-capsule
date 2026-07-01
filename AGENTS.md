# Repository Guidance

This repository is for Quota Capsule: a Codex-first, agent-extensible desktop quota gauge.

## Boundaries

- Do not put DONE / 完事 restroom queue work in this repository.
- Do not put World Cup prediction research work in this repository.
- Keep Codex-specific source probing in `packages/source-codex`.
- Keep provider-neutral quota prediction logic in `packages/core`.
- Keep public product decisions in `docs/decisions`.

## Safety

- Never log or commit `.env`, auth tokens, cookies, local Codex auth state, private keys, certificates, or raw credentialed monitor state.
- Never run `codex logout`, clear Codex auth, reinstall Codex, or replace Codex binaries unless the user explicitly asks for that exact action.
- Treat data-source probing as read-only. Do not automate upstream service actions.
- If quota data cannot be read reliably, return an explicit unknown/error state.

## Product Direction

- The first supported provider is Codex.
- Public wording should make the architecture agent-extensible, so other agent communities can contribute adapters.
- The project value is not displaying a percentage. It is turning usage-window data into a direct judgment: can the user make it to reset at the current pace?

## Development Order

1. Validate source fields with local probes.
2. Build core model and prediction tests.
3. Build desktop mock UI states.
4. Add real source adapters only after the field source is proven.
5. Mac 本地体验优先：桌面悬浮小胶囊为默认形态，菜单栏作为入口和补充控制。
6. Chrome 独立版并行推进；Windows native 放到后续用户需求更明确之后。
