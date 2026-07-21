# Quota Capsule / 额度胶囊

语言：[简体中文](README.zh-CN.md) | [English](README.en.md) | [中英双语](README.md)

**一个本地优先、面向 Codex 重度用户的 macOS 额度判断胶囊。**

> 按现在这个速度，我能不能撑到下一次周额度重置？

![额度胶囊收起与展开状态](docs/assets/product/quota-capsule-expanded.png)

## 为什么做

额度百分比只告诉你已经用了多少，却没有回答一个更直接的工作问题：**现在还能不能放心继续用？**

AI-native 重度用户经常同时运行多个任务，也会反复查看 usage 页面：有时明明还有大量已付费额度，却因为不知道够不够而刻意收着用；有时又在临近重置时才发现还有很多额度没有用完。

额度胶囊把已用额度、时间进度、最近速度、当前活动和可用历史证据合并成一句能直接行动的判断，并显示未来 24 小时建议和重置时的预计余量区间。

它提供六种诚实状态：

- 初步判断：从第一个有效周额度读数开始给出宽区间，并明确标记低置信度。
- 够用：保守预测区间仍能撑到周额度重置。
- 偏快：仍可能撑到重置，但余量区间偏薄。
- 可能不够：即使乐观估计也可能在重置前见底。
- 已用尽：本周额度已经用完，等待重置恢复。
- 数据暂不可用：实时读取失败或数据过期，只保留最后成功百分比，不给速度结论。

Codex 是第一个适配对象。项目保持 agent-extensible：其他 Agent 产品可以添加自己的本地 source adapter，复用同一套额度模型、预测引擎、UI 状态和产品形态。

## 产品形态

额度胶囊尽量安静地常驻，只在用户需要时展开更多信息：

- 桌面悬浮胶囊显示当前判断与周已用比例。
- 菜单栏提供随时可见的一眼状态。
- 展开面板显示时间/用量进度、速度证据、预测置信度、可持续线、重置时间和本地历史。

![额度胶囊收起状态](docs/assets/product/quota-capsule-collapsed.png)

![菜单栏中的额度胶囊](docs/assets/product/quota-capsule-menu-bar.png)

## 当前 Beta

当前公开预发布版本是 [v0.3.4-beta.1](https://github.com/Bono12138/codex-quota-capsule/releases/tag/v0.3.4-beta.1)，已经包括：

- 原生桌面悬浮胶囊和菜单栏入口。
- 只读 Codex app-server rate-limit 数据源。
- 第一次有效读数即给初步估算，并逐步融合周期、近期、活动节奏和历史证据。
- 未来 24 小时建议、最近 24 小时实际用量、重置余量区间和置信原因。
- 分开显示周额度重置、上次成功读取和下次自动读取。
- 带可持续线、预测区间和重置标记的当前周期趋势。
- 本地历史快照，以及隐私安全的重置券数量、到期时间和生命周期历史。
- 多语言界面和公开反馈入口。

完整算法公式、边界和变更规则见 [预测方法](docs/product/forecast-methodology.md)。

## 安装

### 下载当前 Beta

从 [v0.3.4-beta.1 Release](https://github.com/Bono12138/codex-quota-capsule/releases/tag/v0.3.4-beta.1) 下载 `Quota-Capsule-Beta-macOS.zip`。

当前 Beta 使用 ad-hoc 签名，尚未公证。macOS 可能要求在 Finder 中对应用执行**右键 → 打开**。系统要求和 Gatekeeper 处理方式见 [INSTALL.md](INSTALL.md)。

<details>
<summary>使用 Codex 辅助安装</summary>

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
6. 运行 npm ci、npm test、npm run build、npm run audit:repository、swift test 和 swift run QuotaCapsuleCoreSpec。
7. 运行 npm run mac:install，并确认只有一个运行进程来自 /Applications。
8. 如果启动成功，告诉我如何再次打开 Quota Capsule。
9. 如果失败，只给我必要的非敏感错误信息和下一步建议。
```

</details>

<details>
<summary>从源码构建</summary>

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

</details>

## 隐私边界

- 额度数据默认在本机读取和计算。
- 未显式配置 analytics endpoint 并启用相应授权时，不上传产品事件。
- prompt、session、代码、私有路径、账号凭据、auth token 和 cookie 留在本机。
- 重置券原始 ID、描述和 referral 内容不落盘；仅保存 SHA-256 指纹，以及安全的时间和状态事实。
- 缺失或过期数据显示为“数据暂不可用”，不会用旧百分比生成新的安全判断。

## 复用与集成

额度胶囊采用 MIT License。其他 macOS 产品可以整体采用，也可以只复用其中一层：

- `Sources/QuotaCapsuleCore/`：Swift 通用额度模型、预测、历史和只读 Codex 数据源。
- `Sources/QuotaCapsuleMac/`：原生悬浮胶囊、展开面板、菜单栏、设置和本地持久化。
- `packages/core/` 和 `packages/source-codex/`：面向 Web、Chrome 或 adapter 探索的 TypeScript 模型和数据源包。
- `docs/product/`：产品契约、预测方法、验收标准和边界决策。

欢迎按照 [LICENSE](LICENSE) 的条款集成、修改、合并或再发布代码，也欢迎为其他 Agent 产品贡献 source adapter。

## 项目结构

```text
Sources/QuotaCapsuleMac/   macOS 原生悬浮胶囊和菜单栏 app。
Sources/QuotaCapsuleCore/  Swift 通用模型、预测和 Codex app-server source。
apps/desktop/              Vite UI mock，用于 Web/Chrome 视觉探索。
packages/core/             TypeScript 通用额度模型和预测引擎。
packages/source-codex/     Codex-first 本地数据源 probe。
docs/product/              产品简报、预测方法、路线图和验收标准。
docs/decisions/            项目决策记录。
```

## 路线图

- 更完整的新手引导和产品内提示。
- 更长期的历史趋势和使用节奏复盘。
- Chrome 独立版本。
- 更多 Agent provider adapter。
- 内测稳定后补签名、公证和正式 macOS 分发。

## 联系与反馈

- GitHub Issues: <https://github.com/Bono12138/codex-quota-capsule/issues>
- Email: `mmz1218bono@gmail.com`
- X: <https://x.com/starlightsz0>
- 抖音：火腿肠（`huotuichang439`）

<img src="docs/assets/douyin-qr-scan.png" alt="抖音二维码" width="180" />

## 许可证

MIT。详见 [LICENSE](LICENSE)。
