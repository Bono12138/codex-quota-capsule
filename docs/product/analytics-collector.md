# 用户数据采集与分析后台

日期：2026-07-01

## 当前实现

本版已经形成最小闭环：

- macOS app 本地记录 quota snapshot 和产品事件到 SQLite。
- app 按发布通道读取 analytics endpoint：内测版使用 `QUOTA_CAPSULE_PUBLIC_ANALYTICS_ENDPOINT`，开发版使用 `QUOTA_CAPSULE_DEV_ANALYTICS_ENDPOINT`，开发版也兼容旧的 `QUOTA_CAPSULE_ANALYTICS_ENDPOINT`。
- `packages/analytics-collector` 提供一个 Node collector，可本地运行，也可部署到后端服务。
- collector 接收 `POST /v1/events`，校验事件 schema，拒绝明显敏感字段，写入 NDJSON。
- collector 提供 `GET /healthz`。

本地启动：

```sh
PORT=8787 QUOTA_CAPSULE_ANALYTICS_FILE=local-state/analytics/events.ndjson npm run analytics:start
```

开发版指向本地 collector：

```sh
QUOTA_CAPSULE_DEV_ANALYTICS_ENDPOINT=http://127.0.0.1:8787/v1/events npm run mac:run:dev
```

内测版指向公开试用 collector：

```sh
QUOTA_CAPSULE_PUBLIC_ANALYTICS_ENDPOINT=https://example.com/v1/events npm run mac:run:internal-test
```

## 事件层级

### 基础诊断

默认可采集，用来发现安装和数据源问题：

- `app_launched`
- `quota_refresh_started`
- `quota_refresh_succeeded`
- `quota_refresh_failed`
- 版本、界面语言、macOS 主版本、CPU 架构、读取成功/失败、粗略错误类型

### 产品改进数据

用户允许后采集，用来判断产品设计是否值得保留：

- `app_heartbeat`
- `app_quit`
- `quota_state_sampled`
- `capsule_visible`
- `capsule_hidden`
- `capsule_expanded`
- `capsule_collapsed`
- `capsule_resized`
- `capsule_edge_hidden`
- `capsule_edge_revealed`
- `feedback_window_opened`
- `feedback_clicked`
- `feedback_nudge_shown`
- `feedback_nudge_decision`
- `onboarding_started`
- `onboarding_step_viewed`
- `onboarding_completed`
- `onboarding_skipped`
- `language_selected`
- `menu_opened`
- `settings_opened`
- `analytics_consent_changed`
- `local_history_cleared`

`quota_state_sampled` 会发送周窗口用量、周时间进度、可持续日速度、最近速度区间、预计刷新余量区间、预测状态与置信度，以及胶囊宽度分档和展开状态。它不包含 prompt、session、token、文件路径、项目名、窗口标题、代码或命令。

## 明确不采集

collector 会拒绝带有以下字段名的事件：

- prompt
- session
- token
- cookie
- API key
- file path
- project name
- window title
- code
- command
- cwd / path

app 侧也不读取这些内容用于 analytics。

## 后续后台

NDJSON 是第一版可审计落盘格式。正式公开前可以替换为：

- Cloudflare Worker + R2 / D1。
- Supabase Edge Function + Postgres。
- 自建小型 Node 服务 + Postgres。

替换原则：保持 `/v1/events` schema 不变，先保留 collector 的字段拒收逻辑，再增加聚合报表。
