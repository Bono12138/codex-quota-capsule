# Public Launch Materials

日期：2026-07-02

## 发布定位

中文名建议：额度胶囊  
英文名建议：Quota Capsule

一句话：

> 一个 Codex-first 的本地额度续航小胶囊，帮你判断当前使用速度能不能撑到下一次刷新。

当前公开内测重点：

- 先服务 Codex 用户和愿意让 Codex 帮自己安装的开发者。
- 第一分发方式是 GitHub 开源仓库 + Codex-assisted 安装提示词。
- 当前 macOS app 是内测版本，公开用户优先从源码构建和运行。
- 未公证 zip 只作为熟人内测或备用路径。

## 视频脚本

### 标题候选

- 我做了一个 Codex 额度续航胶囊
- 用 Codex 安装一个 Codex 额度工具
- 每次查 Codex 额度太麻烦，所以我做了 Quota Capsule

### 2-3 分钟口播版

大家好，我是 Bono MA。

最近我自己在高强度使用 Codex 和各种 agent 工具的时候，遇到一个很具体的问题：我经常同时跑好几个任务，也会反复去看 usage 或 quota 页面。但一个简单的百分比其实不够用。比如还剩 40%，这到底安全不安全？按我现在这个速度，能不能撑到下一次刷新？如果撑不到，大概几点会见底？

我后来做了一些调研，也看了不少相关项目。比如 QuotaGem、ClaudeBar、Codex Quota Viewer、codex-quota、opencode-quota，还有一些浏览器插件或命令行工具。它们证明了 quota 可视化确实有需求，也有不少做得很认真。但我自己的感受是，有些更像 dashboard，有些偏账号或 session 管理，有些主要在终端里用。它们都很有价值，但我的需求更轻：我只想在工作时扫一眼，就知道现在还能不能继续干活。

所以我做了 Quota Capsule，中文我暂时叫它“额度胶囊”。

它是一个常驻 Mac 桌面和菜单栏的小胶囊。它会读取本机 Codex 的 rate-limit window，把 5 小时窗口和 weekly 窗口转换成更直接的判断：安全、注意、危险、未知。它把时间进度和额度已用放在一起看，告诉你当前速度能不能撑到刷新。

当前这个内测版本已经支持 macOS 原生悬浮胶囊、菜单栏状态、详情面板、自动刷新、手动刷新、三语界面、首次引导、多处反馈入口、Codex 辅助反馈提示词，以及本地历史和可选的产品改进数据。它默认从本机读取，本机计算。prompt、session、token、cookie、代码内容、文件路径这些都留在你的电脑上。

我这次准备把它开源出来。早期分发方式会比较特别：你可以打开 GitHub 仓库，把 README 里的提示词复制给自己的 Codex，让你的 Codex 帮你 clone、检查环境、构建并启动。这样比直接下载一个陌生的未公证 app 更适合第一批 Codex 用户。

后续我想继续做几件事：第一，把新手引导做得更好；第二，做历史趋势和使用节奏复盘；第三，做独立 Chrome 版本；第四，支持更多 agent provider adapter；第五，等产品更稳定后再补签名、公证、DMG、自动更新这些正式分发能力。

这个项目完全开源。你可以自己 fork、自己改、自己定制。如果你发现 bug，欢迎去 GitHub Issues 提；如果你想支持其他工具，也欢迎提 adapter request 或直接 PR。你也可以通过邮箱、X、抖音联系我。后面如果感兴趣的人比较多，我也可以拉一个群，大家一起讨论怎么把它做得更好。

项目地址放在评论区或简介里。欢迎试用，也欢迎挑毛病。

### 30 秒短版

我做了一个 Codex 额度续航小工具，叫 Quota Capsule，中文暂时叫“额度胶囊”。

它解决的问题很简单：还剩 40% 额度时，我到底能不能撑到下一次刷新？它会常驻 Mac 桌面和菜单栏，把 Codex 的 5 小时窗口和 weekly 窗口变成安全、注意、危险、未知这些直接判断。

项目完全开源。早期安装方式是把 GitHub 里的提示词交给自己的 Codex，让 Codex 帮你在本机 clone、构建和启动。prompt、session、token、代码内容都留在本机。

欢迎去 GitHub 试用、提 issue、提 PR。也欢迎关注我的抖音、X，后面人多的话我会拉群一起讨论。

## Codex-assisted 安装提示词模板

把下面这段发给自己的 Codex：

```text
请帮我在本机安装并运行 Quota Capsule。

项目地址：
https://github.com/Bono12138/codex-quota-capsule

请严格遵守这些安全边界：
1. 先阅读 README.md、INSTALL.md、AGENTS.md 和 package.json。
2. 只做本地 clone、依赖安装、构建、测试和启动。
3. 不要退出我的 Codex 登录，不要重装、卸载、降级或替换 Codex。
4. 不要读取、复制或输出我的 auth token、cookie、API key、Codex session 正文、prompt 正文、代码内容或私有文件路径。
5. 不要上传我的数据。除非我明确配置 analytics endpoint，否则不要配置任何远程上报。
6. 不要使用 sudo，不要修改 shell profile、LaunchAgents、系统设置或浏览器扩展。
7. 如果缺 Node、npm、Swift、Xcode Command Line Tools 或 Codex CLI，先告诉我缺什么，让我决定是否安装。

请按这个流程执行：
1. clone 仓库到一个合适的本地目录。
2. 进入仓库目录。
3. 运行 npm ci。
4. 运行 npm test。
5. 运行 npm run build。
6. 运行 swift run QuotaCapsuleCoreSpec。
7. 运行 npm run mac:run:internal-test -- --verify。
8. 如果启动成功，告诉我如何再次打开 Quota Capsule。
9. 如果失败，只给我必要的非敏感错误信息和下一步建议。
```

## 手动安装命令

```bash
git clone https://github.com/Bono12138/codex-quota-capsule.git
cd codex-quota-capsule
npm ci
npm test
npm run build
swift run QuotaCapsuleCoreSpec
npm run mac:run:internal-test -- --verify
```

## 发布前安全审查命令

在 private 工作仓库运行：

```bash
npm run public:prepare
```

输出目录：

```text
artifacts/public-repo-staging/
```

检查文件：

```text
artifacts/public-repo-staging/PUBLIC_STAGING_AUDIT.md
```

只有这个 staging directory 适合推到 public 仓库。不要把 private 工作仓库整体改成公开仓库。

## 当前市场调研引用

已经记录在本仓库：

- `docs/research/competitors/2026-07-01-competitor-visual-and-product-archive.md`
- `docs/research/competitors/2026-07-01-competitor-trial-stage.md`

可在公开视频中点名但不使用第三方截图的项目：

- QuotaGem: https://github.com/gyozalab/QuotaGem
- ClaudeBar: https://github.com/tddworks/ClaudeBar
- Codex Quota Viewer: https://github.com/Half-Melon/Codex-Quota-Viewer
- codex-quota / CQ: https://github.com/deLiseLINO/codex-quota
- opencode-quota: https://github.com/slkiser/opencode-quota

公开视频里只讲产品形态和差异，不把未确认授权的竞品截图放进公开仓库。
