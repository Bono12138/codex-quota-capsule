# Quota Capsule

语言：[简体中文](README.zh-CN.md) | [English](README.en.md)

Quota Capsule 是一个 Codex-first 的额度续航小胶囊。它把原始 quota window 数据翻译成用户真正想知道的问题：

> 按现在这个速度，我能不能撑到下一次刷新？如果撑不到，预计几点见底？

第一适配对象是 Codex，但项目会保持 agent-extensible：其他 Agent 产品可以添加自己的本地 source adapter，复用同一套 quota model、预测引擎、UI 状态和产品形态。

## 为什么做

重度 agent 用户经常同时跑多个 coding task，也会反复查看 usage 页面。单纯的百分比不够用，因为“还剩 40%”并不能告诉用户现在这个速度是否安全。

Quota Capsule 要做成一个小而常驻的状态物，直接说人话：

- Safe / 安全：大概率够用到刷新。
- Watch / 注意：暂时够用，但余量不多。
- Danger / 危险：大概率会在刷新前见底。
- Unknown / 未知：数据源缺失、过期或无法读取。

## 当前状态

项目已经有第一版可本地试用的 macOS app：core model、prediction engine、只读 Codex app-server rate-limit adapter、snapshot record、Quiet Glass Capsule UI、菜单栏入口和可分发 zip 包都已建立。

当前 macOS 原生 app 使用真实本地 Codex rate-limit 数据。浏览器/Vite demo 保留为视觉原型和 Web/Chrome 版本探索用。

## 项目结构

```text
Sources/QuotaCapsuleMac/   macOS 原生悬浮胶囊 + 菜单栏 app。
Sources/QuotaCapsuleCore/  Swift 原生 provider-neutral model、预测、Codex app-server source。
apps/desktop/              Vite 桌面 UI mock；用于 Web/Chrome 视觉探索。
packages/core/             provider-neutral quota model、预测引擎、状态文案。
packages/source-codex/     Codex-first 本地数据源 probe 和未来 adapter。
docs/product/              产品简报、MVP 范围、路线图和验收标准。
docs/research/             数据源验证。
docs/decisions/            项目决策记录。
scripts/                   本地 helper scripts。
```

## Codex-first，agent-extensible

产品先服务 Codex，因为这是当前最明确的痛点。

对外表达不要把它限制成只能用于 Codex：

- Codex 是第一个支持的 provider。
- source adapter 是 provider-specific。
- core prediction logic 是 provider-neutral。
- 欢迎其他 agent 社区适配自己的 quota window 和 quota semantics。

## 本地开发

Codex-assisted 安装是早期推荐的公开试用方式，详细说明见 [INSTALL.md](INSTALL.md)。

```bash
npm ci
npm test
npm run build
npm run dev
```

运行 macOS 原生内测版：

```bash
npm run mac:run:internal-test
```

生成公开内测 macOS zip：

```bash
npm run mac:package:internal-test
```

输出文件：

```text
dist/internal-test/Quota-Capsule-Beta-macOS.zip
```

开发版和内测版在本机分开：

```bash
# 内测版：默认指向 public GitHub Issues
npm run mac:run:internal-test

# 开发版：需要显式配置 private Issues URL
QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL="https://github.com/<owner>/<private-repo>/issues" npm run mac:run:dev
```

运行只读 Codex rate-limit probe：

```bash
npm run probe:codex:rate-limits
```

这个命令会通过 `codex -s read-only -a untrusted app-server` 调用 `account/rateLimits/read`，输出脱敏后的 quota snapshot、续航 prediction 和本地 snapshot record。它不读取 prompt、session 正文或 auth token。

## 联系与反馈

- GitHub Issues: <https://github.com/Bono12138/codex-quota-capsule/issues>
- Email: `mmz1218bono@gmail.com`
- X: <https://x.com/starlightsz0>
- 抖音：火腿肠（`huotuichang439`），应用内可直接打开抖音短链

扫码关注抖音，也可以把新的意见发给我：

![抖音二维码](docs/assets/douyin-qr-scan.png)

## 隐私边界

- 默认本地读取、本地计算。
- 未配置 analytics endpoint 时不上传产品事件。
- 配置 analytics endpoint 后，基础诊断和产品改进数据按授权分层发送；prompt、session、代码内容、文件路径和账号凭据留在本机。
- 不收集 account content。
- 不记录 auth token、cookie、private key 或 session 文件内容。
- 缺失或过期数据显示为 `unknown`，不能显示为 `safe`。

## 许可证

MIT。详见 [LICENSE](LICENSE)。
