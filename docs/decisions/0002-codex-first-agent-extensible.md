# Decision 0002: Codex-first，但支持其他 Agent 扩展

日期：2026-07-01

## 决策

Quota Capsule 先为 Codex 设计，但架构和公开表达要支持其他 Agent 产品。

## 影响

- 第一个 source adapter 是 `source-codex`。
- 核心预测逻辑不能依赖 Codex-specific 字段名。
- 后续 adapter 使用 `source-<provider>` package pattern。
- README 可以说 `Codex-first`，不要说 `Codex-only`。
- 公开贡献说明应邀请其他 agent 社区适配自己的产品。

