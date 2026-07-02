# Quota Capsule 安装与使用

## 适用范围

当前包是 macOS 内部测试版，公开试用渠道为 GitHub public 仓库：

```text
https://github.com/Bono12138/codex-quota-capsule
```

- 需要 macOS 14 或更新版本。
- 需要本机已经安装并登录 Codex。
- 需要本机能找到 `codex` 命令，常见路径包括 `~/.local/bin/codex`、`/opt/homebrew/bin/codex`、`/usr/local/bin/codex`。
- 当前包尚未经过 Apple Developer ID 公证，所以第一次打开可能被 Gatekeeper 拦截。

## 本机安装

从仓库根目录生成安装包：

```bash
npm run mac:package:internal-test
```

生成的文件在：

```text
dist/internal-test/Quota-Capsule-Beta-macOS.zip
```

安装方式：

1. 解压 `Quota-Capsule-Beta-macOS.zip`。
2. 把 `Quota Capsule Beta.app` 拖到 `/Applications`。
3. 第一次打开时，如果系统提示无法验证开发者，右键点击 app，选择“打开”。

如果仍然被拦截，可以对这个内部测试包执行：

```bash
xattr -dr com.apple.quarantine "/Applications/Quota Capsule Beta.app"
open "/Applications/Quota Capsule Beta.app"
```

## 版本通道

本仓库当前支持两个本机通道：

| 通道 | 应用名 | Bundle ID | 本地数据目录 | 默认反馈入口 |
| --- | --- | --- | --- | --- |
| 内测版 | `Quota Capsule Beta.app` | `com.bono.quota-capsule.beta` | `~/Library/Application Support/Quota Capsule Beta` | public GitHub Issues |
| 开发版 | `Quota Capsule Dev Local.app` | `com.bono.quota-capsule.dev` | `~/Library/Application Support/Quota Capsule Dev Local` | 需要显式配置 private Issues URL |

两个版本的 app 包也放在不同构建目录：

```text
dist/internal-test/Quota Capsule Beta.app
dist/development/Quota Capsule Dev Local.app
```

两个版本的进程名不同，允许同时打开做对比：

- 内测版进程：`QuotaCapsuleBeta`
- 开发版进程：`QuotaCapsuleDevLocal`

内测版命令：

```bash
npm run mac:run:internal-test
```

开发版命令：

```bash
QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL="https://github.com/<owner>/<private-repo>/issues" npm run mac:run:dev
```

如果开发版没有配置 `QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL`，应用不会显示 GitHub Issues 按钮，避免把开发问题误提交到 public 仓库。

## Codex-assisted 安装

早期公开试用优先使用 Codex-assisted 安装，让用户的本机 Codex 读取仓库、检查环境、构建并启动。

可以把下面这段发给自己的 Codex：

```text
请帮我在本机安装并运行 Quota Capsule：
1. 打开 https://github.com/Bono12138/codex-quota-capsule
2. 先阅读 README、INSTALL.md 和 AGENTS.md。
3. 不要修改我的 Codex 登录状态，不要退出登录，不要重装 Codex。
4. 只允许做本地构建和启动；analytics endpoint 需要我明确配置后才可以使用。
5. 检查我本机是否有 Node、npm、Swift、Codex CLI。
6. 如果缺依赖，先告诉我缺什么，不要擅自安装系统级软件。
7. clone 仓库到一个合适的本地目录。
8. 运行 npm ci。
9. 运行 npm test。
10. 运行 npm run build。
11. 运行 swift run QuotaCapsuleCoreSpec。
12. 运行 npm run mac:run:internal-test -- --verify。
13. 启动成功后，告诉我如何再次打开它。
```

这条路径适合 Codex 用户、开发者和愿意让本机 Codex 帮忙安装的人。

如果缺少 Node、npm、Swift 或 Codex CLI，Codex 应先说明缺什么，并避免使用 `sudo` 或改动系统级环境。

## 使用方式

启动后会出现两个入口：

- 右上角桌面悬浮小胶囊：默认常驻显示当前状态。
- 菜单栏图标：常驻显示状态和 5 小时已用比例，可立即刷新、显示/隐藏悬浮胶囊、打开反馈和引导、退出应用。

胶囊默认显示：

- `安全 17% / 注意 68% / 危险 92% / 未知`
- 颜色表示风险，百分比表示 5 小时窗口已用比例
- 正常状态保持安静；读取失败时显示状态提示，菜单栏可手动刷新

首次启动会显示轻量引导，说明本机只读、隐私边界、状态颜色含义和菜单栏操作。

点击胶囊可展开详情：

- 时间进度
- 额度已用
- 当前速度倍率，不显示无语义进度条
- 刷新余量
- 周额度余量
- 本周压力预测
- 刷新时间
- 最近更新时间

胶囊可以拖动位置。当前内部测试版为了避免透明浮窗在展开/收起时出现残影，展开和收起采用即时切换，不做弹簧动效。

## 给同事使用

发给同事这个文件即可：

```text
dist/internal-test/Quota-Capsule-Beta-macOS.zip
```

建议同时附上这段说明：

```text
这是 Quota Capsule 的 macOS 内部测试版。

使用前请确认：
1. 你已经安装并登录 Codex。
2. 你的电脑能在终端运行 codex --version。
3. 解压后把 Quota Capsule Beta.app 拖到 Applications。
4. 第一次打开如被系统拦截，请右键 app -> 打开。
5. 如果仍然打不开，在终端执行：
   xattr -dr com.apple.quarantine "/Applications/Quota Capsule Beta.app"
   open "/Applications/Quota Capsule Beta.app"

这个版本只在本地读取 Codex 的 rate-limit window。未配置 analytics endpoint 时不上传产品事件；不读取 prompt/session 正文，不切换账号。
```

## 隐私边界

应用只调用本地：

```text
codex -s read-only -a untrusted app-server
account/rateLimits/read
```

它只使用 rate-limit window 字段：

- 5 小时窗口已用比例
- 5 小时窗口刷新时间
- 周窗口已用比例
- 周窗口刷新时间

这些内容保持在本机：

- prompt 内容。
- session 正文。
- auth token。
- Codex 账号状态。
- Codex 配置。

如果用户主动配置 analytics endpoint，应用会按“基础诊断”和“产品改进数据”两层记录和发送。产品改进数据需要用户授权；prompt、session、代码内容、文件路径、账号凭据、token 和 cookie 留在本机。

analytics endpoint 按通道配置：

```bash
# 内测版：公开试用数据
QUOTA_CAPSULE_PUBLIC_ANALYTICS_ENDPOINT="https://example.com/v1/events" npm run mac:run:internal-test

# 开发版：内部研发数据
QUOTA_CAPSULE_DEV_ANALYTICS_ENDPOINT="http://127.0.0.1:8787/v1/events" npm run mac:run:dev
```

内测版不读取 `QUOTA_CAPSULE_ANALYTICS_ENDPOINT` 这个旧的通用变量，避免把公开试用数据误发到开发通道。开发版仍兼容该变量，方便本地调试。

## 故障排查

如果胶囊显示“未知”：

1. 打开终端，确认：

```bash
codex --version
npm run probe:codex:rate-limits
```

2. 如果 `codex --version` 不存在，先修复 Codex CLI 安装或 PATH。
3. 如果 `npm run probe:codex:rate-limits` 返回 error，说明本机 Codex app-server 暂时读不到额度。
4. 退出并重开 Quota Capsule，或从菜单栏点击“立即刷新”。

## 反馈入口

第一版反馈以邮箱和 GitHub Issues 为主：

- Email: `mmz1218bono@gmail.com`
- GitHub Issues: <https://github.com/Bono12138/codex-quota-capsule/issues>
- X: <https://x.com/starlightsz0>
- 抖音：火腿肠（`huotuichang439`）

应用内“关于与反馈”面板提供打开抖音、扫码和复制抖音号。也可以扫码关注抖音并提交新的意见：

![抖音二维码](docs/assets/douyin-qr-scan.png)

## 当前限制

- 这是 ad-hoc signed 内部测试包，尚未经过正式公证。
- 目前只做 macOS 版本。
- 目前没有应用版本自动更新；额度数据会每 60 秒自动刷新。
- 目前没有持久化历史页面，历史快照会在后续版本加入。
