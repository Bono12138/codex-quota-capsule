# Quota Capsule

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

当前最重要的两件事是：

1. 证明 Codex quota 数据可以在本地以只读方式可靠获取。
2. 证明 UI 体验足够好，值得用户让它常驻桌面。

当前 macOS 原生 app 使用真实本地 Codex rate-limit 数据。浏览器/Vite demo 仍保留为视觉原型和 Web/Chrome 版本探索用。

## 项目结构

```text
Sources/QuotaCapsuleMac/   macOS 原生悬浮胶囊 + 菜单栏 app。
Sources/QuotaCapsuleCore/  Swift 原生 provider-neutral model、预测、Codex app-server source。
apps/desktop/              Vite 桌面 UI mock；用于 Web/Chrome 视觉探索。
packages/core/             provider-neutral quota model、预测引擎、状态文案。
packages/source-codex/     Codex-first 本地数据源 probe 和未来 adapter。
docs/product/              产品简报、MVP 范围、策略、商业化。
docs/research/             数据源验证、竞品、视觉研究。
docs/decisions/            项目决策记录。
scripts/                   本地 helper scripts。
```

## Codex-first，但不是 Codex-only

产品先服务 Codex，因为这是当前最明确的痛点。

但对外表达不要把它限制成只能用于 Codex：

- Codex 是第一个支持的 provider。
- source adapter 是 provider-specific。
- core prediction logic 是 provider-neutral。
- 欢迎其他 agent 社区适配自己的 quota window 和 quota semantics。

## 第一阶段开发门槛

1. 确认本地能读到 Codex quota 字段；如果不能，也要明确记录不可用原因。
2. 固定共享 quota data model。
3. 用 mock 数据测试 prediction engine。
4. 做出小而常驻的 capsule UI mock。
5. 做 Mac 桌面悬浮胶囊原型。
6. 搭 Chrome 独立版 mock-first scaffold。
7. 把真实 Codex adapter 接入 Mac 本地壳层，替换桌面 UI 的 mock source。
8. Windows native packaging 放到需求更明确之后。

## 产品研究

- [产品简报](docs/product/brief.md)
- [MVP 范围](docs/product/mvp-scope.md)
- [产品策略与商业化思考](docs/product/strategy-and-commercialization.md)
- [功能路线图](docs/product/feature-roadmap.md)
- [视觉设计方向](docs/product/visual-design-direction.md)
- [开发规划与需求采纳记录](docs/product/development-plan.md)
- [Bug triage 与发布阻塞规则](docs/product/bug-triage-and-release-blockers.md)
- [发布渠道与仓库拆分决策](docs/decisions/0004-release-channels-and-repository-split.md)
- [Codex-assisted 分发策略](docs/distribution/codex-assisted-distribution-strategy.md)
- [Public 仓库文件清单](docs/distribution/public-repo-file-manifest.md)
- [竞品视觉与产品档案](docs/research/competitors/2026-07-01-competitor-visual-and-product-archive.md)
- [竞品本地试用记录](docs/research/competitors/2026-07-01-competitor-trial-stage.md)

## 本地开发

Codex-assisted 安装是早期推荐的公开试用方式，详细说明见 [INSTALL.md](INSTALL.md)。

```bash
npm install
npm test
npm run build
npm run dev
```

运行 macOS 原生 app：

```bash
npm run mac:run
```

生成可发给同事的 macOS zip：

```bash
npm run mac:package
```

输出文件：

```text
dist/Quota-Capsule-macOS.zip
```

详细安装、使用、分发说明见 [INSTALL.md](INSTALL.md)。

运行当前 Codex probe：

```bash
npm run probe:codex
```

当前 probe 是保守的。它只记录本地 Codex CLI 暴露了什么，不抓取 secrets，不记录 auth token，也不把旧数据伪装成新数据。

运行只读 Codex rate-limit probe：

```bash
npm run probe:codex:rate-limits
```

这个命令会通过 `codex -s read-only -a untrusted app-server` 调用 `account/rateLimits/read`，输出脱敏后的 quota snapshot、续航 prediction 和本地 snapshot record。它不读取 prompt、session 正文或 auth token。

## 隐私边界

- 默认本地读取、本地计算。
- 不上传 usage data。
- 不收集 account content。
- 不记录 auth token、cookie、private key 或 session 文件内容。
- 缺失或过期数据显示为 `unknown`，不能显示为 safe。

## License

MIT
