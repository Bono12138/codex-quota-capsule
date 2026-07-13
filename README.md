# Quota Capsule / 额度胶囊

Languages: [简体中文](README.zh-CN.md) | [English](README.en.md)

Quota Capsule is a small macOS quota runway capsule for heavy Codex users.

额度胶囊是一个面向 Codex 重度用户的 macOS 桌面小胶囊。

It answers the question a bare quota percentage cannot answer:

> At the current pace, can I keep working until the next reset?

它把 quota window 数据翻译成用户真正关心的判断：

> 按现在这个速度，我能不能撑到下一次周额度重置？

## Why This Exists / 为什么做

Heavy Codex users often run multiple tasks, check usage pages repeatedly, and still hold back even with paid quota available. A percentage is only evidence. The working decision is whether the current pace can last until reset.

很多 Codex 重度用户会同时跑多个任务，也会反复查看 usage 页面。百分比只能提供证据。真正影响工作节奏的是：现在还能不能继续放心用。

Quota Capsule stays visible on the desktop and in the menu bar, then turns weekly quota pace into six honest states and a next-24-hour budget:

额度胶囊常驻桌面和菜单栏，把周额度速度转换成六个明确状态和未来 24 小时建议：

- Early estimate / 初步判断：从第一个有效周额度读数开始给出宽区间判断，并明确显示低置信度。
- On track / 够用：保守预测区间仍能撑到周额度重置。
- Running fast / 偏快：仍可能撑到重置，但余量区间已经偏薄。
- May run out / 可能不够：即使乐观估计也可能在重置前见底。
- Exhausted / 已用尽：本周额度已经用完，等待重置恢复。
- Data unavailable / 数据暂不可用：实时读取失败或数据过期，只保留最后成功百分比，不给速度结论。

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
8. Run npm run mac:install and verify exactly one running process comes from /Applications.
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
npm run mac:install
```

## Privacy Boundary / 隐私边界

- By default, quota data is read and computed locally.
- Product events are not uploaded unless an analytics endpoint is explicitly configured.
- Prompt text, session text, code content, private file paths, account credentials, auth tokens, and cookies stay on this Mac.
- Missing or stale quota data is shown as `Data unavailable`, with stale percentages clearly marked.

- 默认本地读取、本地计算。
- 未显式配置 analytics endpoint 时，不上传产品事件。
- prompt 正文、session 正文、代码内容、私有文件路径、账号凭据、auth token、cookie 留在本机。
- 缺失或过期数据显示为“数据暂不可用”，过期百分比会被明确标记。

## One App / 唯一应用

The public repository builds one `Quota Capsule Beta.app`. Development uses branches, tests, and previews rather than a second persistent app identity. This prevents duplicate capsules and keeps local history in one Beta data directory.

公开仓库只构建一个 `Quota Capsule Beta.app`。开发使用分支、测试和预览，不再安装第二个常驻应用，避免重复胶囊和数据目录分裂。

## Current Status / 当前状态

The first public beta is a macOS app built from source. It currently includes:

- Native floating desktop capsule and menu bar item.
- Read-only Codex app-server rate-limit source.
- Immediate first-reading estimate plus adaptive cycle, recent, activity, and historical pace evidence.
- Next-24-hour budget, last-24-hour usage, reset-balance range, and plain-language confidence.
- Separate weekly-reset, last-successful-read, and next-automatic-read timing.
- Current-cycle trend with a sustainable line, forecast band, and reset marker.
- Local history snapshots.
- Multilingual UI.
- Feedback links for GitHub Issues, email, X, and Douyin.

当前公开内测版是从源码构建的 macOS app，已经包括：

- 原生桌面悬浮胶囊和菜单栏入口。
- 只读 Codex app-server rate-limit 数据源。
- 第一次有效读数即给初步估算，并融合周期、近期、活动节奏和历史先验证据。
- 未来 24 小时建议、最近 24 小时实际用量、重置余量区间和置信原因。
- 分开显示周额度重置、上次成功读取和下次自动读取。
- 带可持续线、预测区间和重置标记的当前周期趋势。
- 本地历史快照。
- 多语言界面。
- GitHub Issues、邮箱、X、抖音反馈入口。

算法公式、边界和变更规则见 [Forecast Methodology / 预测方法](docs/product/forecast-methodology.md)。

## Roadmap / 路线图

- Better onboarding and in-product guidance.
- Longer-term history and usage-rhythm review.
- Chrome version.
- More agent provider adapters.
- Signed, notarized, packaged macOS distribution after the beta stabilizes.

- 更完整的新手引导和产品内提示。
- 更长期的历史趋势和使用节奏复盘。
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
