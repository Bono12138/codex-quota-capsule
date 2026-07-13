# 数据源 Probe 计划

## 当前假设

Codex 是第一个 provider，但稳定的本地 quota source 还没有完全证明。

项目不能默认假设某个 CLI 命令或本地文件一定暴露 quota 数据。第一阶段目标是做只读 probe，记录本地到底能读到什么、缺什么。

## 需要的字段

理想 source adapter 返回：

- provider
- source status：`ok`、`stale` 或 `error`
- fetched time
- weekly window duration
- weekly used percent
- weekly remaining percent
- weekly reset time

## Probe 规则

- 只读。
- 不记录 secrets。
- 不复制 auth files。
- 不调用 `codex logout`。
- 不重装、降级、替换 Codex。
- 缺失字段就是 missing，不能当作 0。
- 过期字段就是 stale，不能当作 fresh。

## 第一阶段 Probe

第一版本地 probe 记录：

- `codex --version`
- `codex --help` 暴露的顶层 CLI commands
- `codex debug --help` 暴露的 debug commands
- 是否存在 usage/quota 相关命令

这个 probe 故意很保守。它先确认公开本地 CLI surface 是否提供结构化 usage 路径，再决定是否进入更深的数据源调查。
