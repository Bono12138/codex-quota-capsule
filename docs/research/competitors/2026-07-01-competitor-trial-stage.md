# 竞品本地试用记录

日期：2026-07-01

后续汇总文档：

- `docs/research/competitors/2026-07-01-competitor-visual-and-product-archive.md`：可复用的视觉档案、产品形态分析、定位总结。
- `docs/product/strategy-and-commercialization.md`：当前产品策略与商业化判断。

## 目标

在继续投入 Quota Capsule 前，先评估已有 quota 工具，判断我们应该独立做、给上游贡献，还是调整方向。

## 用户要求

- Chrome 版本要做成独立版本。
- 阅读用户粘贴的 ChatGPT 竞品调研。
- 先从这些项目里挑选安全、适合本地试用的项目，配置到本地。
- 再比较产品是否重叠，判断独立做还是基于已有项目贡献/修改。

## 本地试用目录

外部竞品项目放在主仓库外：

```text
/Users/Zhuanz/Documents/quota-competitor-lab
```

## 安全规则

- 先读源码和 README，再决定是否运行。
- 不运行会修改 shell profile、launch agents、浏览器 profile、auth 状态或 Codex binary 的 install script。
- 不粘贴、不暴露 API key、cookie、token、Codex auth file、原始 session 数据。
- 优先使用 demo / mock / offline 模式。
- 跳过的项目必须记录原因。

## 已验证项目

| 项目 | URL | 本地路径 | 试用状态 |
| --- | --- | --- | --- |
| QuotaGem | https://github.com/gyozalab/QuotaGem | `/Users/Zhuanz/Documents/quota-competitor-lab/QuotaGem` | 前端 dev server 已跑在 `http://127.0.0.1:5174/`；完整产品是 Windows/Tauri app，没有在这台 Mac 上跑完整 app。 |
| Codex Quota Viewer | https://github.com/Half-Melon/Codex-Quota-Viewer | `/Users/Zhuanz/Documents/quota-competitor-lab/Codex-Quota-Viewer` | Swift release binary 和 `.app` 构建成功。因为包含 account/config/session mutation 能力，没有自动打开真实环境。 |
| ClaudeBar | https://github.com/tddworks/ClaudeBar | `/Users/Zhuanz/Documents/quota-competitor-lab/ClaudeBar` | 只 clone 和阅读。需要 Tuist 和完整 macOS app setup，不作为第一批安全试用。 |
| codex-quota / CQ | https://github.com/deLiseLINO/codex-quota | `/Users/Zhuanz/Documents/quota-competitor-lab/codex-quota` | 构建成功。已创建并测试安全 mock TUI 脚本。 |
| opencode-quota | https://github.com/slkiser/opencode-quota | `/Users/Zhuanz/Documents/quota-competitor-lab/opencode-quota` | 使用 scripts disabled 的方式安装并构建成功。已在隔离 config 下测试 `show --json`。 |

## 本地试用入口

在 `/Users/Zhuanz/Documents/quota-competitor-lab` 下运行：

```bash
./run-codex-quota-demo.sh
```

这个脚本用临时 fake HOME、fake Codex/OpenCode auth file、项目自带 mock usage server 运行 `codex-quota`。它不会读写真实 `~/.codex`。

```bash
./run-opencode-quota-show.sh
```

这个脚本在隔离 OpenCode config 下运行 `opencode-quota show --provider synthetic --json`。当前 synthetic 不可用是预期结果，因为隔离环境没有配置真实 cache/auth。

```bash
./run-codex-quota-viewer-isolated.sh
```

这个脚本用隔离 fake HOME 启动构建好的 Codex Quota Viewer。只建议用于 UI 观察。正常 app 有账号切换、配置写入、session 管理、backup/rollback 能力。

另外：

```text
http://127.0.0.1:5174/
```

这是 QuotaGem 前端 panel dev server。它适合看视觉密度和 provider 布局，但不等于真实 Windows tray app。

## 安全备注

- QuotaGem 使用 `npm install --ignore-scripts` 后，production dependency audit 为 0 vulnerabilities；完整 Tauri/Windows runtime 没有在这台 Mac 上运行。
- Codex Quota Viewer 构建成功，但它 bundled session manager dependencies 在竞品构建时报告过 audit vulnerabilities。这是竞品试用风险，不是我们项目风险。
- Codex Quota Viewer 和 codex-quota 都包含 account/config switching 能力。真实数据试用时，不要点 switch/apply/account mutation 动作，除非先做单独备份。
- ClaudeBar 没有构建，因为它需要 Tuist 和完整 macOS app setup。它对架构和 UI 参考有价值，但不是最低风险的第一批试用项目。

## 发现

### 产品重叠

Quota Capsule 和这些工具在 quota 可见性、5h/weekly window、reset time、provider adapter、状态颜色上都有重叠。

最接近 Windows 路线的直接竞品是 QuotaGem。它已经有：

- Windows tray-first 产品形态。
- compact 和 expanded 面板。
- Claude、Codex、Antigravity providers。
- 5h 和 weekly usage。
- Codex app-server source，以及 `.codex/sessions` JSONL fallback。
- warning/danger thresholds、notifications、theme controls、launch-at-login。

Codex Quota Viewer 在 macOS menu bar 和 Codex 数据源上重叠明显，但产品更重：account vault、account switching、config writing、local session manager、repair/rollback。

codex-quota 在数据和账号管理上有重叠，但它是终端产品，不是 consumer-facing 常驻 UI。

opencode-quota 在 provider 广度和 quota command surface 上有重叠，但它是 OpenCode 集成，不是独立桌面 capsule。

ClaudeBar 在 macOS menu bar multi-provider status 上有重叠，但它的产品命题是 broad monitoring，不是单一 calm capsule。

### 值得保留的差异

Quota Capsule 不应该竞争“又一个 quota dashboard”。

真正值得保留的差异是：

- 默认常驻的小型 floating capsule。
- 直接给人话判断：safe、watch、danger、unknown。
- 用“时间进度 vs 额度已用”解释判断。
- 5h window 是主状态；weekly quota 是辅助压力。
- Chrome 独立版是轻量跨平台分发路径。
- Codex-first，但 adapter-friendly，不做多账号/session 管理软件。

### 数据源意义

QuotaGem 和 Codex Quota Viewer 都确认：

```text
codex app-server
account/rateLimits/read
```

是一个实际可用的 source path。

Codex Quota Viewer 会用 read-only/untrusted sandbox args 启动 Codex；QuotaGem 会把 `usedPercent`、`windowDurationMins`、`resetsAt` 映射成 usage window。

Quota Capsule 应该把当前 source probe 从 CLI help inspection 升级为只读 app-server rate-limit probe。

### 独立做还是贡献上游

建议：**Quota Capsule 独立做，但可以给上游贡献小修复或 source adapter 经验。**

原因：

- UX 目标不同。已有项目更像 dashboard、menu bar、TUI/account manager 或 OpenCode plugin。
- QuotaGem 在 Windows 很接近，但它是 multi-provider tray monitoring，不是围绕“我现在还能不能继续干活”的小胶囊。
- Codex Quota Viewer 太重，还会改变 Codex config/session 状态；基于它做会把 Quota Capsule 拖进更重的产品类别。
- opencode-quota 适合作为 integration/plugin 参考，但不是 desktop overlay 产品。

## 产品决策草案

继续把 Quota Capsule 做成独立项目，但定位收窄：

> Codex-first 的 quota runway capsule。不管理账号，不切换 auth，不默认做 dashboard。它回答：当前速度能不能撑到刷新；需要时再展开解释。

Mac 本地体验主线优先；Chrome 版本做成独立版并同步搭骨架；Windows native 放到后面，根据 Mac/Chrome 反馈再决定。

## 下一步建议

1. 给 `packages/source-codex` 增加 Codex app-server rate-limit probe。
2. 在 README 或 docs 里诚实写出竞品矩阵：QuotaGem、ClaudeBar、Codex Quota Viewer、codex-quota、opencode-quota。
3. Chrome 独立版先围绕 mock source 做原型，再验证浏览器是否能安全访问可靠 source。
4. MVP 明确排除 account switching 和 session management。

