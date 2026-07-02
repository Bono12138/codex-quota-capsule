# Quota Capsule

Languages: [简体中文](README.zh-CN.md) | [English](README.en.md)

Quota Capsule is a small macOS quota gauge for heavy Codex users. It turns quota-window data into a direct question:

> At the current pace, can I make it to the next reset? If not, when will I run out?

Quota Capsule 是一个面向 Codex 重度用户的 macOS 额度小胶囊。它把 quota window 数据翻译成用户真正关心的问题：

> 按现在这个速度，我能不能撑到下一次刷新？如果撑不到，预计几点见底？

## What It Does / 它能做什么

- Shows a quiet floating capsule and a menu bar status item.
- Reads local Codex rate-limit windows through a read-only Codex app-server call.
- Predicts whether the current pace can last until reset.
- Supports 5-hour and weekly quota windows.
- Keeps the first version Codex-first while leaving the model agent-extensible.

- 显示桌面悬浮胶囊和菜单栏状态。
- 通过只读 Codex app-server 调用读取本地 rate-limit window。
- 判断当前速度能不能撑到刷新。
- 支持 5 小时窗口和周窗口。
- 第一版先服务 Codex，同时保留其他 Agent 产品适配空间。

## Quick Start / 快速开始

Read the full setup guide before running the app:

```text
INSTALL.md
```

早期公开试用推荐使用 Codex-assisted 安装。把下面这段交给自己的 Codex：

```text
Please install and run Quota Capsule on this Mac:
1. Open https://github.com/Bono12138/codex-quota-capsule
2. Read README.md, INSTALL.md, and AGENTS.md first.
3. Do not modify my Codex login state, log me out, or reinstall Codex.
4. Only do local clone, dependency install, build, test, and launch.
5. If Node, npm, Swift, or Codex CLI is missing, tell me before changing the system.
6. Run npm ci, npm test, npm run build, swift run QuotaCapsuleCoreSpec.
7. Run npm run mac:run:internal-test -- --verify.
8. After it launches, tell me how to open it again.
```

Manual install:

```bash
git clone https://github.com/Bono12138/codex-quota-capsule.git
cd codex-quota-capsule
npm ci
npm test
npm run build
swift run QuotaCapsuleCoreSpec
npm run mac:run:internal-test -- --verify
```

## Local Channels / 本机版本通道

| Channel | App | Purpose |
| --- | --- | --- |
| Internal test | `Quota Capsule Beta.app` | Public beta build; feedback goes to public GitHub Issues. |
| Development | `Quota Capsule Dev Local.app` | Local owner/developer build; private issue URL must be configured explicitly. |

## Privacy Boundary / 隐私边界

- By default, the app reads and computes locally.
- Product events are not uploaded unless an analytics endpoint is explicitly configured.
- Prompts, session text, code, file paths, account credentials, tokens, and cookies stay on this Mac.
- Missing or stale quota data must be shown as `unknown`, not `safe`.

- 默认本地读取、本地计算。
- 未显式配置 analytics endpoint 时不上传产品事件。
- prompt、session 正文、代码、文件路径、账号凭据、token、cookie 留在本机。
- 缺失或过期数据显示为 `unknown`，不能显示为 `safe`。

## Feedback / 反馈

- GitHub Issues: <https://github.com/Bono12138/codex-quota-capsule/issues>
- Email: `mmz1218bono@gmail.com`
- X: <https://x.com/starlightsz0>
- Douyin / 抖音：火腿肠（`huotuichang439`）

![Douyin QR code](docs/assets/douyin-qr-scan.png)

## License / 许可证

MIT. See [LICENSE](LICENSE).
