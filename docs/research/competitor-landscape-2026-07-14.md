# Codex 额度工具竞品更新

日期：2026-07-14
状态：可公开分享的当前快照
决策对象：Quota Capsule 的产品定位、发布文案和后续路线

## Executive Summary

- **这不是空白市场。** CodexBar、ClaudeBar、`usage`、codexU、onWatch 等项目仍在高频更新；菜单栏监控、多 provider 聚合、历史分析和账号管理都已经有成熟或快速成长的产品。
- **“Weekly Only”符合当前实测，但不是永久上游合同。** 2026-07-14 15:13（北京时间），本机 Codex CLI `0.144.2` 的只读 `account/rateLimits/read` 只返回一个 `10080` 分钟（7 天）窗口。OpenAI 当前公开帮助页只说明额度随计划变化，并未承诺 5 小时窗口永久取消。因此 Quota Capsule 应继续只展示当前可靠的周窗口，同时保留未来识别其他窗口的解析能力。
- **Quota Capsule 的可信差异不是“别人只显示百分比”。** 部分竞品已经有 burn rate、pace-aware 颜色、历史趋势、悬浮窗口或重置券到期时间。我们更准确的差异是：把周额度变成一个带置信度的工作判断，并在同一条低打扰体验中给出能否撑到重置、未来 24 小时预算、预测区间、过期保护和重置券生命周期。
- **建议继续独立维护，但定位必须更窄。** 不做多账号切换、代理路由或大而全 dashboard；优先把“判断是否可持续”做得比通用监控工具更可信、更容易理解。

## 调研口径

本次只使用可复核的一手资料：

- 各项目的 GitHub 仓库、README、最新 Release 和默认分支最近提交；
- OpenAI 官方帮助页、官方定价页和官方 Release Notes；
- 本机只读 `codex app-server` 实测，仅记录窗口数量、时长和是否有重置时间，不记录或发布任何凭据、账号信息或原始响应。

GitHub 星标和版本信息是 2026-07-14 的快照，只用来说明可见度和维护活跃度，不代表产品质量。没有重新运行全部竞品，也没有把第三方截图复制进本仓库。

## 上游额度变化：当前是周窗口，长期仍需动态适配

OpenAI 当前的 [Codex plan 帮助页](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan) 表述为：Codex、ChatGPT Work 等功能共享 agentic usage/credit pool，具体额度随计划和任务变化；接近或达到限制时，以 Codex usage 页面或 banner 为准。官方 [Codex 定价页](https://developers.openai.com/codex/pricing) 也只说明不同计划拥有不同使用量，没有公开固定窗口协议。

本机当前实测：

```text
观察时间：2026-07-14 15:13:09 +08:00
Codex CLI：0.144.2
来源：codex app-server / account/rateLimits/read（只读）
返回窗口：1 个
窗口时长：10080 分钟（7 天）
```

竞品也在为这个变化补兼容：

- [Codex Quota Viewer](https://github.com/Half-Melon/Codex-Quota-Viewer) 已明确写出 weekly-only plan 会按 weekly-only 展示。
- [codexU v1.0.4](https://github.com/shanggqm/codexU/releases/tag/v1.0.4) 在 2026-07-13 修复了“只返回 7 天窗口时被误标为 5 小时额度”的问题。
- [CodexBar v0.42.1](https://github.com/steipete/CodexBar/releases/tag/v0.42.1) 增加了周重置确认，并抑制临时或跨账号样本造成的错误恢复提示。
- QuotaGem、`usage`、onWatch 和 Quota Float 的公开文案仍以 5 小时 + 周窗口为主要信息结构；这可能仍适用于部分账户、模型或旧响应，但不能当作当前所有 Codex 用户的统一事实。

因此当前产品规则应当是：

> 正常界面只展示数据源当前可靠返回的周额度；解析层按窗口时长识别而不是按 primary/secondary 槽位猜测。未来若短窗口重新稳定出现，再通过独立产品评审恢复，而不是让旧假设自动渗回界面。

## 当前竞品矩阵

| 项目 | 2026-07-14 快照 | 主要形态 | 当前优势 | 与 Quota Capsule 的边界 |
| --- | --- | --- | --- | --- |
| [CodexBar](https://github.com/steipete/CodexBar) | `v0.42.1`，18,164 stars，7/14 仍有提交 | macOS 菜单栏 + CLI + WidgetKit | 约 58 个 provider、成熟安装/更新、状态页、成本和额度历史、重置券到期 | 广度和成熟度显著领先；核心是多 provider 监控，不以 Codex 周续航判断为唯一第一任务 |
| [ClaudeBar](https://github.com/tddworks/ClaudeBar) | `v0.4.71`，1,317 stars，7/13 发布 | macOS 菜单栏 dashboard | 多 provider、签名公证、通知、可配置刷新、pace-aware 状态 | 有节奏意识，但产品仍以 provider dashboard 和阈值状态为主 |
| [usage](https://github.com/aqua5230/usage) | `v0.27.1`，254 stars，7/14 发布 | macOS 菜单栏 + pinned 状态 + HTML 报告 | 本地日志、token/成本历史、丰富报告、始终可见 | 可见性与本地分析很强；公开说明仍以 5 小时 + 周窗口和广泛工作流助手为主，没有文档化的周重置余量区间与 24 小时预算 |
| [codexU](https://github.com/shanggqm/codexU) | `v1.0.4`，231 stars，7/13 发布 | macOS 菜单栏 + 完整桌面 dashboard | token 趋势、项目/Skill 排行、任务看板、单周窗口兼容 | 历史和工作看板更强；信息密度高，主要回答“用了什么”，不是“这个节奏是否可持续” |
| [Quota Float](https://github.com/change-42-yhmm/quota-float) | `v0.1.5`，224 stars，7/13 发布 | Windows/macOS 悬浮组件 | 悬浮形态、Codex-only、stale 状态、重置券到期、跨平台构建 | 是最接近的界面形态；公开能力仍是当前百分比、状态和消费指示，没有说明不确定性预测、证据融合或 24 小时预算 |
| [onWatch](https://github.com/onllm-dev/onWatch) | `v2.12.5`，675 stars，6/19 发布 | 跨平台本地 daemon + Web/PWA dashboard | SQLite 历史、burn-rate forecast、周期分析、通知、Grafana/REST | 预测与历史能力强；配置和运维成本更高，产品面向多 provider/团队/FinOps，不是一个安静的原生 Codex 胶囊 |
| [QuotaGem](https://github.com/gyozalab/QuotaGem) | `v2.0.1`，67 stars，6/30 发布 | Windows 托盘 | Windows portable、Tauri、Codex/Claude/Antigravity、紧凑环形 UI | Windows 路线更成熟；主视图仍以 5 小时窗口和固定阈值为中心 |
| [Codex Quota Viewer](https://github.com/Half-Melon/Codex-Quota-Viewer) | `v1.2.0`，72 stars，5/16 发布 | macOS 菜单栏 + 管理中心 | weekly-only 兼容、多账号、配置切换、session 管理和回滚 | Codex 管理能力远强；会进入账号、配置和 session 变更，信任边界与轻量只读胶囊不同 |
| [opencode-quota](https://github.com/slkiser/opencode-quota) | `v3.11.2`，719 stars，7/10 发布 | OpenCode 插件 + CLI/TUI | quota 在工作现场出现、provider 广、JSON/CI、token 报告 | 工作流嵌入和跨 provider 更强；绑定 OpenCode，不是独立桌面续航产品 |
| [CQ / codex-quota](https://github.com/deLiseLINO/codex-quota) | `v0.3.4`，78 stars，7/8 发布 | Go TUI | 快速多账号切换、OAuth、Codex/OpenCode 应用 | 适合终端和多账号用户；不是常驻桌面判断，且账号变更不属于我们的 MVP |
| [Quotio](https://github.com/nguyenphutrong/quotio) | `v0.22.0`，4,554 stars，7/10 仍有提交 | macOS proxy/account command center | provider/账号管理、路由、自动 failover、实时流量和 quota | 更像 AI agent 基础设施；规模大但任务与“周额度能否撑住”不同 |

## Quota Capsule 真正可成立的优势

### 1. 第一屏回答工作决策，而不是展示遥测清单

默认问题只有两个：

1. 按有证据支持的最近速度，本周额度能否撑到重置？
2. 为了保持可持续，未来 24 小时建议最多再用多少？

竞品中已有 pace、forecast 和 threshold，但多数把它们放在多 provider dashboard、历史分析或告警体系里。Quota Capsule 把这个判断本身当作产品，而不是监控系统里的一个字段。

### 2. 对粗粒度百分比保持诚实

上游只给整数百分比和重置时间，不给绝对额度。Quota Capsule 不把一个点估计包装成精确答案，而是：

- 从第一个有效读数给出低置信的初步范围；
- 把整数百分比视为量化区间；
- 融合当前周期、近期、活动时段和历史先验证据；
- 显示预测范围和置信原因；
- 在证据跨越“够用/不够”边界时明确降置信，而不是只改变颜色。

在本次阅读的竞品公开文档中，没有发现另一个项目同时公开说明这套“量化误差 + 多证据融合 + 决策边界置信度”的周额度模型。这个结论仅限公开文档，不等于对所有未公开实现的断言。

### 3. Weekly Only 减少当前无关信息

当前账户只返回周窗口时，继续显示空白或推测的 5 小时区域会制造歧义。Quota Capsule 的正常界面不保留 5 小时占位，不按响应槽位猜窗口类型，也不会让未来短窗口影响当前周预测。

### 4. 低打扰但仍可审计

折叠胶囊只给结论、已用量和节奏；展开后再解释时间进度、最近实际变化、建议预算、趋势、重置时间、数据读取时间和诊断。它比完整 dashboard 更适合长时间常驻，又比单一百分比更容易追问“为什么”。

### 5. 信任边界比账号管理工具窄

Quota Capsule 只读 Codex app-server，不切换账号，不写 `auth.json`/`config.toml`，不自动使用重置券。prompt、session、代码内容和凭据不进入产品历史。重置券只保存不可逆指纹和安全的时间/状态事实。

### 6. 把重置券作为低频但高价值的生命周期数据

展开面板底部显示权威数量、每张券的本地到期分钟和本地历史。它不会把“有券”错误当成“当前周节奏安全”，也不会擅自兑换。这个边界比只显示一个券数量更适合后续研究发放规律和兑换策略。

### 7. 预测和界面有发布级回归约束

Swift 与 TypeScript 共享 fixture；轮询频率、重复平点、reset 抖动、stale 数据和菜单交互都有明确验收。这个优势不是“没有 bug”，而是每次修复必须留下可重复的失败样例和安装态证据。

## 我们目前不占优势的地方

- **生态广度：** CodexBar、ClaudeBar、onWatch、opencode-quota 和 Quotio 支持更多 provider。
- **安装成熟度：** CodexBar、ClaudeBar 等已有 Homebrew、签名/公证或自动更新；Quota Capsule 仍是源码构建/未公证 Beta。
- **历史分析：** `usage`、codexU 和 onWatch 的 token、成本、项目和周期报告更丰富。
- **跨平台：** QuotaGem、Quota Float 和 onWatch 已覆盖 Windows 或跨平台场景。
- **用户规模：** 当前项目仍处于早期公开内测，不能用模型设计替代真实用户验证。

因此不应宣称“功能更多”或“预测最准”。更合适的公开说法是：

> Quota Capsule 是一个 Codex-first、Weekly Only 的本地续航判断工具。它不管理账号，也不做大而全 dashboard；它把粗粒度周额度转成带置信度的可持续判断和未来 24 小时预算。

## 产品与传播建议

1. README 和视频只强调“判断、预算、置信度、低打扰”，不再说竞品都只是静态 dashboard。
2. 正常 UI 继续 Weekly Only；解析层保留按实际窗口时长识别的扩展能力。
3. 每月或 OpenAI 重大更新后刷新本表，重点观察 CodexBar、codexU、Quota Float、`usage` 和 onWatch。
4. 下一阶段优先补正式签名/公证、可解释的历史复盘和真实用户校准，不急着追多 provider 数量。
5. 对外比较坚持“公开 README 能证明什么就写什么”，不使用未经授权的竞品截图，不评价未检查的内部算法。

## 可复核链接

- OpenAI：[Codex plan 帮助页](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan)、[Codex 定价](https://developers.openai.com/codex/pricing)、[ChatGPT / Codex Release Notes](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)
- 直接桌面竞品：[CodexBar](https://github.com/steipete/CodexBar)、[ClaudeBar](https://github.com/tddworks/ClaudeBar)、[`usage`](https://github.com/aqua5230/usage)、[codexU](https://github.com/shanggqm/codexU)、[Quota Float](https://github.com/change-42-yhmm/quota-float)、[QuotaGem](https://github.com/gyozalab/QuotaGem)、[Codex Quota Viewer](https://github.com/Half-Melon/Codex-Quota-Viewer)
- 相邻工具：[onWatch](https://github.com/onllm-dev/onWatch)、[opencode-quota](https://github.com/slkiser/opencode-quota)、[CQ / codex-quota](https://github.com/deLiseLINO/codex-quota)、[Quotio](https://github.com/nguyenphutrong/quotio)
