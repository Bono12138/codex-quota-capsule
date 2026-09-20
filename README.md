# Quota Capsule / 额度胶囊

[简体中文](README.zh-CN.md) · [English](README.en.md) · [下载 Releases](https://github.com/Bono12138/codex-quota-capsule/releases)

面向 Codex 的 macOS 额度工具：查看周额度与 5 小时限制，把剩余周额度分给你实际打算工作的时段。

A local-first macOS quota companion for Codex. See weekly and five-hour limits, then allocate your remaining weekly quota to planned work sessions.

## 这次更新

当前源码开发版本为 **0.5.0**。已公开下载的安装包仍以 [Releases](https://github.com/Bono12138/codex-quota-capsule/releases) 的版本和说明为准；旧版 v0.3.6-beta.1 不包含新的时段预算。源码功能与安装包不能混为一谈。

- 首次使用先确认工作时段、星期、预留额度和今天的任务量。
- 胶囊显示本时段还可用多少周额度；展开后先显示下一刷新点和 5 小时额度。
- 睡觉、休息等未安排的时段不分配预算。跨夜和全天后台任务均可设置。
- 当前时段的分配固定，后续实际用量从中扣除。用户放慢使用，不会让本段分配自动变大。
- 历史速度放在“历史用法参考”中，不用它推断用户没有顾虑时会消耗多少。
- 数据过期、读取失败或重置待确认时暂停预算提示。5 小时额度耗尽会优先提示。
- 重置券到期时间显示到分钟；兑换仍由用户操作，应用不会自动用券。

## 算法示例

剩余 60% 周额度，截止前还有三个各 4 小时的使用时段，预留为 0：
每段分配 20%。本段用了 5%，本段还可用 15%。
如果暂时不使用，本段分配仍是 20%，不会因为时间过去而升高。
到下一时段，再按当时实际余额分配；未用完的额度会留给后续时段。

预算终点取“自然周重置”与“最早已知可用重置券到期”中较早的时间。
这是按到期前手动用券的计划安排，券到期本身不会补满额度。
换模型、并发任务和 5 小时限制仍会影响实际可用性。

[完整算法与边界](docs/product/session-budget-methodology.md) · [设计决定](docs/decisions/0007-session-budget-planning.md)

## 安装和使用

下载公开安装包不需要注册 GitHub。需要 macOS 14 或更新版本，以及已安装并登录的 ChatGPT/Codex 桌面端或兼容 Codex CLI。

1. 从 [Releases](https://github.com/Bono12138/codex-quota-capsule/releases) 下载 ZIP。
2. 解压后将 Quota Capsule Beta.app 放进“应用程序”，只保留这一份安装副本。
3. 打开胶囊，确认“上次成功读取”在更新；在支持时段预算的版本中，点击“设置使用时段”。
4. 通过一级菜单的 Language 切换简体中文、繁體中文或 English。

Beta 采用 ad-hoc 签名，尚未公证。请先阅读 [安装说明](INSTALL.md) 和 [中文新手教程](docs/getting-started.zh-CN.md)。

## 源码开发

```bash
git clone https://github.com/Bono12138/codex-quota-capsule.git
cd codex-quota-capsule
npm ci
npm test
npm run build
npm run lint
npm run audit:repository
npm run audit:quota-surfaces
swift test
swift run QuotaCapsuleCoreSpec
npm run mac:install
```

| 目录 | 用途 |
| --- | --- |
| Sources/QuotaCapsuleCore | Swift 额度模型、时段预算、历史预测、数据源和历史存储 |
| Sources/QuotaCapsuleMac | 正式 macOS 应用：胶囊、菜单、设置、本地状态 |
| Tests | Swift 算法、读数、持久化与渲染测试 |
| packages/core、packages/source-codex | TypeScript 历史预测和只读数据源 |
| apps/desktop | 浏览器预测实验室；暂未实现原生版时段预算 |
| packages/analytics-collector | 可选的、需配置和授权的产品事件收集服务 |
| docs | 当前产品规范、算法、验收和历史决策 |

新预算拆为 UsageBudgetPlanner（纯计算）、UsageBudgetState（本地设置和分配记录）、UsageBudgetViews（原生界面）。不需要重写读数和历史数据库。

## 隐私与限制

额度读取、使用计划和预算分配记录默认在本地处理。账号快照包含跨设备累计消耗，但两次采样之间发生在何时、哪台设备上，无法据此准确还原。

计划和分配记录不上传。已有产品事件只有在显式配置收集地址并获得相应授权后才上传。不会将认证凭据、prompt、代码或私有文件路径提交到仓库。券历史仅保留指纹及安全的时间、状态字段。

目前每个选定工作日支持一个连续时段，精度为整点。支持跨夜、全天、今天任务量权重和预留。多段日程、自动习惯学习、跨设备计划同步，以及提示对使用行为的因果评估尚未实现。预算是分配建议，不保证用户会用完，也不是准确的未来需求预测。

## 文档与贡献

[文档导航](docs/README.md) · [验收标准](docs/product/acceptance-criteria.md) · [版本记录](CHANGELOG.md) · [发布流程](docs/operations/release-checklist.md)

欢迎通过 Issue 提交使用问题，或通过 PR 贡献测试、翻译和其他 Agent 数据源。请使用脱敏截图和合成测试数据。

- [GitHub Issues](https://github.com/Bono12138/codex-quota-capsule/issues)
- Email: mmz1218bono@gmail.com
- [X](https://x.com/starlightsz0)
- 抖音：火腿肠（huotuichang439）

<img src="docs/assets/douyin-qr-scan.png" alt="抖音二维码" width="180" />

MIT License，见 [LICENSE](LICENSE)。
