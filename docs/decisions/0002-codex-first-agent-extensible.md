# Decision 0002: Codex-First, Agent-Extensible

Date: 2026-07-01

## Decision

Quota Capsule is designed for Codex first, but the architecture and public messaging should support other agent products.

## Consequences

- The first source adapter is `source-codex`.
- Core prediction logic must not depend on Codex-specific field names.
- Future adapters should follow the `source-<provider>` package pattern.
- README wording can say "Codex-first" instead of "Codex-only".
- Public contribution prompts should invite other agent communities to adapt the product.

