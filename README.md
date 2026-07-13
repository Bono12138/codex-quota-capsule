# Quota Capsule / 额度胶囊

Languages: [简体中文](README.zh-CN.md) | [English](README.en.md)

Quota Capsule is a small macOS quota runway capsule for heavy Codex users.

额度胶囊是一个面向 Codex 重度用户的 macOS 桌面小胶囊。

It answers the question a bare quota percentage cannot answer:

> At the current pace, can I keep working until the next reset?

它把 quota window 数据翻译成用户真正关心的判断：

> 按现在这个速度，我能不能撑到下一次刷新？

## Why This Exists / 为什么做

Heavy Codex users often run multiple tasks, check usage pages repeatedly, and still hold back even with paid quota available. A percentage is only evidence. The working decision is whether the current pace can last until reset.

很多 Codex 重度用户会同时跑多个任务，也会反复查看 usage 页面。百分比只能提供证据。真正影响工作节奏的是：现在还能不能继续放心用。

Quota Capsule stays visible on the desktop and in the menu bar, then turns weekly quota pace into direct states and a safe daily budget:

额度胶囊常驻桌面和菜单栏，把周额度速度转换成直接状态和今天可持续使用的预算：

- Safe / 安全：当前速度大概率能撑到刷新。
- Watch / 注意：暂时能用，但余量偏薄。
- Danger / 危险：当前速度大概率会在刷新前见底。
- Unknown / 未知：数据缺失、过期或读取失败。

## Who It Is For / 适合谁

- Codex users who often run several tasks at once.
- People who repeatedly check quota or usage pages while working.
- Developers who want a local-first quota gauge they can inspect and modify.
- Agent communities that want to add their own quota source adapters.

- 经常同时跑多个 Codex 任务的用户。
- 工作时反复查看额度或 usage 页面的人。
- 想要本地优先、可检查、可修改工具的开发者。
- 想为其他 Agent 产品贡献 source adapter 的社区。

## Quick Start / 快速开始

Early public testing uses GitHub + Codex-assisted installation. Open this repository and give the prompt below to your own Codex:

早期公开试用采用 GitHub + Codex-assisted 安装。打开本仓库，把下面这段交给自己的 Codex：

```text
Please install and run Quota Capsule on this Mac:
1. Open https://github.com/Bono12138/codex-quota-capsule
2. Read README.md, INSTALL.md, AGENTS.md, and package.json first.
3. Do not modify my Codex login state, log me out, reinstall Codex, or replace Codex binaries.
4. Only do local clone, dependency install, build, test, and launch.
5. Do not read, copy, print, or upload auth tokens, cookies, API keys, prompt text, session text, code content, or private file paths.
6. If Node, npm, Swift, Xcode Command Line Tools, or Codex CLI is missing, tell me before changing the system.
7. Run npm ci, npm test, npm run build, and swift run QuotaCapsuleCoreSpec.
8. Run npm run mac:install:internal-test and verify the running process comes from /Applications.
9. After it launches, tell me how to open it again.
```

Manual install:

```bash
git clone https://github.com/Bono12138/codex-quota-capsule.git
cd codex-quota-capsule
npm ci
npm test
npm run build
swift run QuotaCapsuleCoreSpec
npm run mac:install:internal-test
```

## Privacy Boundary / 隐私边界

- By default, quota data is read and computed locally.
- Product events are not uploaded unless an analytics endpoint is explicitly configured.
- Prompt text, session text, code content, private file paths, account credentials, auth tokens, and cookies stay on this Mac.
- Missing or stale quota data is shown as `unknown`.

- 默认本地读取、本地计算。
- 未显式配置 analytics endpoint 时，不上传产品事件。
- prompt 正文、session 正文、代码内容、私有文件路径、账号凭据、auth token、cookie 留在本机。
- 缺失或过期数据显示为 `unknown`。

## Local Channels / 本机版本通道

| Channel | App | Purpose |
| --- | --- | --- |
| Internal test | `Quota Capsule Beta.app` | Public beta build; feedback goes to public GitHub Issues. |
| Development | `Quota Capsule Dev Local.app` | Local owner/developer build; private issue URL must be configured explicitly. |

## Current Status / 当前状态

The first public beta is a macOS app built from source. It currently includes:

- Native floating desktop capsule and menu bar item.
- Read-only Codex app-server rate-limit source.
- Weekly pace, reset-buffer, and daily-budget prediction.
- Local history snapshots.
- Multilingual UI.
- Feedback links for GitHub Issues, email, X, and Douyin.

当前公开内测版是从源码构建的 macOS app，已经包括：

- 原生桌面悬浮胶囊和菜单栏入口。
- 只读 Codex app-server rate-limit 数据源。
- 周速度、刷新余量和今日可用预算预测。
- 本地历史快照。
- 多语言界面。
- GitHub Issues、邮箱、X、抖音反馈入口。

## Roadmap / 路线图

- Better onboarding and in-product guidance.
- History trends and usage rhythm review.
- Chrome version.
- More agent provider adapters.
- Signed, notarized, packaged macOS distribution after the beta stabilizes.

- 更完整的新手引导和产品内提示。
- 历史趋势和使用节奏复盘。
- Chrome 独立版本。
- 更多 Agent provider adapter。
- 内测稳定后补签名、公证和正式 macOS 分发。

## Feedback / 反馈

- GitHub Issues: <https://github.com/Bono12138/codex-quota-capsule/issues>
- Email: `mmz1218bono@gmail.com`
- X: <https://x.com/starlightsz0>
- Douyin / 抖音：火腿肠（`huotuichang439`）

![Douyin QR code](docs/assets/douyin-qr-scan.png)

## License / 许可证

MIT. See [LICENSE](LICENSE).
