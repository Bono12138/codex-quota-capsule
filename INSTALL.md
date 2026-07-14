# Quota Capsule 安装与使用

## 系统要求

- macOS 14 或更新版本。
- 已安装并登录 Codex，终端可运行 `codex --version`。
- Node.js、npm、Swift 和 Xcode Command Line Tools。
- 当前 Beta 使用 ad-hoc 签名，尚未经过 Apple Developer ID 公证。

公开仓库是唯一安装来源：<https://github.com/Bono12138/codex-quota-capsule>。

## Codex-assisted 安装

可以把下面的提示交给本机 Codex：

```text
请从 https://github.com/Bono12138/codex-quota-capsule 安装 Quota Capsule。
先阅读 README.md、INSTALL.md、AGENTS.md 和 package.json。
不要退出或修改我的 Codex 登录状态，不要重装或替换 Codex。
不要读取、打印或上传 token、cookie、prompt、session、代码或私有文件路径。
检查 Node、npm、Swift、Xcode Command Line Tools 和 Codex CLI。
运行 npm ci、npm test、npm run build、npm run audit:repository、swift test 和 swift run QuotaCapsuleCoreSpec。
运行 npm run mac:install，并确认只有一个 Quota Capsule Beta.app，运行进程来自 /Applications。
```

## 手动安装

```bash
git clone https://github.com/Bono12138/codex-quota-capsule.git
cd codex-quota-capsule
npm ci
npm test
npm run build
npm run audit:repository
swift test
swift run QuotaCapsuleCoreSpec
npm run mac:install
```

唯一应用身份：

| 项目 | 值 |
| --- | --- |
| App | `Quota Capsule Beta.app` |
| Bundle ID | `com.bono.quota-capsule.beta` |
| Process | `QuotaCapsuleBeta` |
| Data | `~/Library/Application Support/Quota Capsule Beta` |
| Build output | `dist/beta/Quota Capsule Beta.app` |
| Zip | `dist/beta/Quota-Capsule-Beta-macOS.zip` |

如果首次打开被 Gatekeeper 拦截，请在 Finder 中右键应用并选择“打开”。必要时：

```bash
xattr -dr com.apple.quarantine "/Applications/Quota Capsule Beta.app"
open "/Applications/Quota Capsule Beta.app"
```

## 使用方式

- 桌面胶囊显示周额度判断、周已用比例、时间/用量进度和重置倒计时。
- 点击展开后可查看未来 24 小时预算、预测区间、速度证据、重置时间和数据更新时间。
- 展开面板最下方显示当前重置券权威数量，以及 app-server 已返回的每张可用券到期时间（本机时区，精确到分钟）。
- 菜单栏可手动刷新、显示/隐藏胶囊、打开反馈和退出。
- 后台每 60 秒自动读取；读取失败时保留最后成功数据并明确标记为旧数据。

“周额度重置时间”和“数据更新时间”是两个不同概念，界面会分别显示。

## 隐私边界

应用只读调用本机 Codex app-server 的 `rateLimits/read`，使用周额度窗口和重置券事实。它不读取或上传 prompt、session、代码、项目路径、token、cookie 或账号凭据。重置券原始 ID 会立即转换为 SHA-256 指纹，description/referral 内容不进入模型或数据库；发放、到期和生命周期事实保存在本机，清空本地历史时一并删除。

远程 analytics 默认不会发送到任何地方。只有显式设置下面的 endpoint 后才可能上传允许的产品事件：

```bash
QUOTA_CAPSULE_PUBLIC_ANALYTICS_ENDPOINT="https://example.com/v1/events" npm run mac:run
```

产品改进事件仍受应用内 consent 控制。原始额度历史保存在本机 SQLite。

## 构建与打包

```bash
npm run mac:run
npm run mac:package
codesign --verify --deep --strict --verbose=2 "dist/beta/Quota Capsule Beta.app"
```

## 故障排查

如果显示“数据暂不可用”：

```bash
codex --version
npm run probe:codex:rate-limits
```

确认 CLI 可用且已登录。找不到 CLI、未登录、读取超时、字段缺失和数据过期会显示不同诊断；应用不会修改 Codex 安装或登录状态。

如果出现两个胶囊，维护者应先运行 `./script/retire_legacy_dev.sh --dry-run`。只有本地退休归档已经完成并通过校验时，才允许使用 `--apply`；普通用户不需要此步骤。

## 反馈

- GitHub Issues: <https://github.com/Bono12138/codex-quota-capsule/issues>
- Email: `mmz1218bono@gmail.com`
- X: <https://x.com/starlightsz0>
- 抖音：火腿肠（`huotuichang439`）
