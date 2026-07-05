# Quota Capsule / 额度胶囊

语言：[简体中文](README.zh-CN.md) | [English](README.en.md)

额度胶囊是一个面向 Codex 重度用户的 macOS 桌面额度小胶囊。它把 quota window 数据翻译成一个工作判断：

> 按现在这个速度，我能不能撑到下一次刷新？

Codex 是第一个适配对象。项目会保持 agent-extensible：其他 Agent 产品可以添加自己的本地 source adapter，复用同一套 quota model、预测引擎、UI 状态和产品形态。

## 为什么做

重度 Codex 用户经常同时跑多个 coding task，也会反复查看 usage 页面。百分比只能提供证据。真正影响工作节奏的是：

- 现在还能不能继续用？
- 当前速度能不能撑到刷新？
- 如果撑不到，预计几点见底？
- 如果能撑到，刷新时大概还有多少余量？

额度胶囊要做成一个小而常驻的状态物，直接给出判断：

- Safe / 安全：当前速度大概率能撑到刷新。
- Watch / 注意：暂时能用，但余量偏薄。
- Danger / 危险：当前速度大概率会在刷新前见底。
- Unknown / 未知：数据源缺失、过期或读取失败。

## 适合谁

- 经常同时跑多个 Codex 任务的用户。
- 工作时反复查看 usage 或 quota 页面的人。
- 希望本地读取、本地计算、能检查源码的开发者。
- 想为其他 Agent 产品贡献 quota source adapter 的社区。

## 当前状态

项目已经有第一版可本地试用的 macOS app：

- 原生桌面悬浮胶囊。
- 菜单栏状态入口。
- 只读 Codex app-server rate-limit adapter。
- 5 小时窗口和周窗口预测。
- 本地历史快照。
- 多语言界面。
- 公开反馈入口。

当前 macOS 原生 app 使用真实本地 Codex rate-limit 数据。浏览器/Vite demo 保留为视觉原型和 Web/Chrome 版本探索用。

## 快速开始

早期公开试用推荐使用 Codex-assisted 安装。打开本仓库，把下面这段交给自己的 Codex：

```text
请帮我在本机安装并运行 Quota Capsule。

项目地址：
https://github.com/Bono12138/codex-quota-capsule

请严格遵守这些安全边界：
1. 先阅读 README.md、INSTALL.md、AGENTS.md 和 package.json。
2. 只做本地 clone、依赖安装、构建、测试和启动。
3. 不要退出我的 Codex 登录，不要重装、卸载、降级或替换 Codex。
4. 不要读取、复制、输出或上传 auth token、cookie、API key、Codex session 正文、prompt 正文、代码内容或私有文件路径。
5. 如果缺 Node、npm、Swift、Xcode Command Line Tools 或 Codex CLI，先告诉我缺什么，让我决定是否安装。
6. 运行 npm ci。
7. 运行 npm test。
8. 运行 npm run build。
9. 运行 swift run QuotaCapsuleCoreSpec。
10. 运行 npm run mac:run:internal-test -- --verify。
11. 如果启动成功，告诉我如何再次打开 Quota Capsule。
12. 如果失败，只给我必要的非敏感错误信息和下一步建议。
```

手动安装：

```bash
git clone https://github.com/Bono12138/codex-quota-capsule.git
cd codex-quota-capsule
npm ci
npm test
npm run build
swift run QuotaCapsuleCoreSpec
npm run mac:run:internal-test -- --verify
```

## 本机版本通道

| 通道 | App | 用途 |
| --- | --- | --- |
| Internal test | `Quota Capsule Beta.app` | 公开内测版，反馈默认进入 public GitHub Issues。 |
| Development | `Quota Capsule Dev Local.app` | 本机开发版，private issue URL 需要显式配置。 |

运行公开内测版：

```bash
npm run mac:run:internal-test
```

运行开发版：

```bash
QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL="https://github.com/<owner>/<private-repo>/issues" npm run mac:run:dev
```

## 隐私边界

- 默认本地读取、本地计算。
- 未配置 analytics endpoint 时，不上传产品事件。
- 配置 analytics endpoint 后，基础诊断和产品改进数据按授权分层发送。
- prompt 正文、session 正文、代码内容、私有文件路径、账号凭据、auth token、cookie 留在本机。
- 缺失或过期数据显示为 `unknown`。

## 项目结构

```text
Sources/QuotaCapsuleMac/   macOS 原生悬浮胶囊 + 菜单栏 app。
Sources/QuotaCapsuleCore/  Swift 原生 provider-neutral model、预测、Codex app-server source。
apps/desktop/              Vite 桌面 UI mock；用于 Web/Chrome 视觉探索。
packages/core/             provider-neutral quota model、预测引擎、状态文案。
packages/source-codex/     Codex-first 本地数据源 probe 和未来 adapter。
packages/analytics-collector/  可选产品改进数据接收端。
docs/product/              产品简报、MVP 范围、路线图和验收标准。
docs/distribution/         分发策略、公开仓库清单和宣传材料。
docs/decisions/            项目决策记录。
scripts/                   本地 helper scripts。
```

## 路线图

- 更完整的新手引导和产品内提示。
- 历史趋势和使用节奏复盘。
- Chrome 独立版本。
- 更多 Agent provider adapter。
- 内测稳定后补签名、公证、DMG 和自动更新。

## 联系与反馈

- GitHub Issues: <https://github.com/Bono12138/codex-quota-capsule/issues>
- Email: `mmz1218bono@gmail.com`
- X: <https://x.com/starlightsz0>
- 抖音：火腿肠（`huotuichang439`）

扫码关注抖音，也可以把新的意见发给我：

![抖音二维码](docs/assets/douyin-qr-scan.png)

## 许可证

MIT。详见 [LICENSE](LICENSE)。
