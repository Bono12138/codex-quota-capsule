# 功能路线图

日期：2026-07-01

## 核心原则

我们可以吸收竞品的功能，但不能让这些功能破坏 Quota Capsule 的主营体验。

主营体验只有一个：

> 常驻小胶囊，扫一眼知道现在还能不能继续干活。

所以功能分层如下：

1. **默认层**：只显示额度续航判断。
2. **解释层**：点击或 hover 后解释为什么。
3. **历史层**：查看过去用量快照、消耗趋势和时段分析。
4. **设置层**：主题、阈值、通知、显示模式、provider。
5. **高级层**：多 provider、CLI/JSON、导出、团队策略。
6. **敏感层**：账号切换、session 管理、配置写入。默认不做，后续即使做也应是独立高级模块。

## 主营功能

### 1. 额度续航判断

这是产品的核心，不允许被其他功能挤掉。

默认展示：

- 安全 / 注意 / 危险 / 未知。
- 能不能撑到刷新。
- 如果撑不到，预计几点见底。
- 如果能撑到，刷新时预计剩多少。

计算依据：

- 时间进度。
- 额度已用。
- 当前 burn rate。
- 剩余时间。
- 剩余额度。

### 2. 常驻显示

第一优先级：

- Mac 桌面悬浮小胶囊。

可选显示：

- Mac 菜单栏。
- Chrome toolbar popup。
- Chrome 页面 overlay / pinned badge。
- 后续 Windows tray / always-on-top capsule。

### 3. 数据可靠性

必须明确显示数据状态：

- 正常。
- 过期。
- 读取失败。
- 缺权限。
- source 不支持。

读取失败不能显示成绿色安全状态。

## 吸收竞品功能

### 来自 QuotaGem

应该吸收：

- compact / expanded 两层结构。
- 环形用量图，可用于详情层或多 provider 页面。
- warning / danger threshold 设置。
- 通知设置：全部提醒 / 只提醒危险 / 关闭。
- 主题、透明度、缩放。
- provider visibility controls。
- 启动时自动运行。
- Windows tray 形态，后续再做。

不放进默认层：

- 多 provider dashboard。
- 大面积 expanded panel。
- 复杂设置入口。

### 来自 ClaudeBar

应该吸收：

- 视觉完成度标准。
- 菜单栏入口。
- 多主题机制。
- pace-aware 状态。
- provider tabs 的组织思路，后续用于高级页。

不放进默认层：

- 大渐变 dashboard。
- 多卡片 provider 面板。
- 泛 AI monitor 的默认定位。

### 来自 Codex Quota Viewer

应该吸收：

- `codex app-server` / `account/rateLimits/read` 数据源思路。
- stale data 标记。
- 读取失败时的人话说明。
- 菜单栏作为可选入口。

谨慎处理：

- account vault。
- auth switching。
- config writing。
- session manager。

这些能力先不进入 Quota Capsule MVP。未来如果要做，也应该作为独立“高级工具箱”或另一个 companion product，不能进入默认胶囊体验。

### 来自 codex-quota

应该吸收：

- 安全 mock/demo 模式。
- keyboard-first 快速操作思路。
- 终端用户可能需要的 CLI 入口。

不放进默认层：

- TUI 主界面。
- 账号切换主流程。

### 来自 opencode-quota

应该吸收：

- 多 surface 输出：status line、toast、sidebar、command、JSON。
- CLI `show`。
- JSON 输出，方便后续接其他工具。
- 项目级 / 全局级配置思路。

不放进默认层：

- 复杂配置安装。
- 绑定单一工具生态。

## 快照数据功能

用户明确希望产品像“打点计时器”一样，持续记录一些快照数据，用来查看过去用量和某个时段的消耗。

这是非常有价值的方向，但要做成本地优先、隐私清楚的时间序列数据。

### 快照记录什么

每次采样记录一个 capture，并为 5 小时窗口和 weekly 窗口分别写入 window record。

capture 级字段：

- `timestamp`
- `provider`
- `source`
- `source_status`
- `fetched_at`
- `data_age_seconds`
- `app_version`
- `schema_version`
- `error_type`
- `error_message_hash`

window 级字段：

- `window_type`：5h / weekly / other
- `window_minutes`
- `used_percent`
- `remaining_percent`
- `resets_at`
- `window_start`
- `time_elapsed_percent`
- `minutes_until_reset`
- `burn_rate_percent_per_min`
- `burn_rate_vs_even_pace`
- `estimated_empty_at`
- `projected_remaining_at_reset`
- `state`：safe / watch / danger / unknown
- `used_delta_percent`
- `delta_minutes`
- `delta_percent_per_min`
- `reset_detected`

本地事件指标：

- app 启动。
- 胶囊展开/收起。
- 胶囊宽度调整。
- 手动刷新。
- 读取成功/失败。
- 引导开始/完成/跳过。
- 反馈入口点击。
- 抖音打开、抖音号复制。
- GitHub Issues / email / X 点击。

不记录：

- prompt 内容。
- session 内容。
- auth token。
- cookie。
- API key。
- 原始 Codex session 文件内容。
- 文件路径、项目名、窗口标题或可反推具体工作内容的数据。

### 快照频率

建议默认：

- 正常状态：每 1 分钟记录一次。
- 读取失败：记录 failure snapshot，但同类失败做节流。
- 数据不变时可以去重。
- 窗口 reset 前后保留连续记录，方便分析刷新点。

### 存储方式

下一版直接使用本地 SQLite。

- 支持 schema version 和迁移。
- 支持按时间范围查询。
- 支持清空历史数据。
- 支持 retention 设置。
- 后续支持导出 CSV / JSON。

### 保留周期

默认建议：

- 原始快照保留 30 天。
- 5 分钟或小时聚合保留 180 天。
- 天级聚合长期保留，用户可关闭。

空间预估：

- 每分钟采样一次，每次写 5h 和 weekly 两条 window record，每天约 2880 条。
- 30 天约 86400 条 window record。
- SQLite 空间通常在几十 MB 级别，即使加索引和聚合也应控制在 100 MB 量级。
- 需要在设置或诊断页显示当前历史库大小，并提供清空入口。

### 可以做出的分析

第一阶段：

- 今天哪个时段消耗最快。
- 最近 5h window 的 burn rate。
- 刷新前是否经常提前见底。
- 本周 quota 压力是否异常。

第二阶段：

- 按项目 / workspace 估算消耗。
- 长任务启动后的消耗曲线。
- 多 agent 并行时的消耗变化。
- 用量异常提醒。

注意：项目 / workspace 维度不能通过读取文件路径或 prompt 内容实现。只有在未来有明确、可解释、用户同意的本地标签机制后再评估。

### UI 入口

不要把历史图表放进默认胶囊。

建议入口：

- 胶囊点击后，详情 popover 里有一个小入口：`历史`。
- 历史页打开后显示：
  - 今日曲线。
  - 最近 5 小时窗口。
  - 本周趋势。
  - 快照列表。
  - 导出按钮。

## 产品分析与用户使用数据

owner 明确需要远程产品分析，用来判断产品是否真的被常驻使用、用户在哪些地方流失、哪些版本或语言环境问题最多。

### 产品问题

远程分析要回答：

- 有多少真实安装在持续使用。
- 日活、周活、月活和 D1 / D7 / D30 留存。
- 用户是否长期保持悬浮胶囊显示。
- 用户是否经常展开详情面板。
- 首次引导在哪一步跳过或失败。
- 读取失败集中在哪些版本、macOS 主版本或 locale。
- 抖音、Email、GitHub Issues、X 哪个反馈入口更常被点击。
- 常驻菜单栏和悬浮胶囊的组合是否有价值。

### 远程事件字段

事件公共字段：

- `event_id`
- `event_name`
- `event_time`
- `install_id_hash`
- `app_version`
- `schema_version`
- `locale`
- `macos_major_version`
- `arch`
- `analytics_consent_version`

事件属性：

- `surface`：capsule / menu_bar / onboarding / feedback / settings / diagnostics
- `provider`：codex
- `status`：safe / watch / danger / unknown
- `source_status`：success / stale / failed / missing_cli / auth_required / timeout
- `error_type`
- `duration_seconds`
- `count`
- `width_bucket`
- `language`
- `feedback_target`：email / github / x / douyin_open / douyin_copy
- `short_used_percent` / `short_elapsed_percent` / `projected_remaining_at_reset_percent`
- `weekly_used_percent` / `weekly_elapsed_percent` / `weekly_projected_remaining_percent`

### 首批事件

- `app_launched`
- `app_quit`
- `app_heartbeat`
- `capsule_visible`
- `capsule_hidden`
- `capsule_expanded`
- `capsule_collapsed`
- `capsule_resized`
- `capsule_edge_hidden`
- `capsule_edge_revealed`
- `menu_opened`
- `settings_opened`
- `quota_refresh_started`
- `quota_refresh_succeeded`
- `quota_refresh_failed`
- `quota_state_sampled`
- `onboarding_started`
- `onboarding_step_viewed`
- `onboarding_completed`
- `onboarding_skipped`
- `language_selected`
- `feedback_window_opened`
- `feedback_clicked`
- `analytics_consent_changed`
- `local_history_cleared`

### 采集边界

远程产品分析严禁上传：

- prompt、session 正文、代码内容、终端命令。
- auth token、cookie、API key、原始 Codex session 文件。
- 文件路径、项目名、窗口标题、联系人、邮箱正文。
- 具体 quota 原始响应。
- 可反推用户正在做什么项目的内容。

### 下一版工程形态

- 本地保留事件队列，用于失败重试和调试。
- 上报 adapter 独立封装，便于后续切换 Cloudflare、Supabase、PostHog 或自建 endpoint。
- endpoint 未配置时，事件留在本地开发日志和队列，不静默发送。
- 首次引导和设置里显示三语采集说明。
- CI 检查 analytics 事件名和 schema 字段，避免随手新增不可追踪字段。

## 功能优先级

### P0

- 续航判断引擎。
- Mac 悬浮小胶囊 mock。
- 只读 Codex source proof。
- Unknown / stale / error 状态。
- 本地快照数据模型设计。

### P1

- 真实 Codex adapter。
- 本地 snapshot writer。
- 远程产品分析 consent、事件队列和上报 adapter。
- 三语 string catalog、首屏语言判断和缺失 key 检查。
- 分步新手引导和诊断引导。
- 基础历史页：今日快照、5h 消耗曲线。
- 通知。
- 菜单栏。
- 胶囊有限尺寸调整和显示偏好。

### P2

- 多 provider adapter。
- Chrome 独立版真实 source 方案。
- CLI / JSON 输出。
- 主题和视觉定制。
- CSV / JSON 导出。
- Windows native。

### P3

- 团队策略包。
- 高级历史分析。
- workspace / project 维度估算。
- 企业 adapter。
- 敏感高级工具箱：账号/session/config，默认不启用。
