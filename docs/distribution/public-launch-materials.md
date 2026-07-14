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

本轮拆分出三个专项文档：

- `docs/distribution/launch-video-materials-requirements.md`：录屏、截图、口播和 README 素材清单。
- `docs/distribution/launch-video-production-brief.md`：抖音视频大纲、标题、口播文案、X 文本和 GitHub 承接策略。
- `docs/distribution/quota-anxiety-psychology-notes.md`：额度焦虑背后的心理学资料和可引用说法。

### DBSkill 辅助策划框架（2026-07-05）

本轮用项目内 `dontbesilent2025/dbskill` 子集做内容策划，不直接生成逐字稿。使用方式：

- `dbs-diagnosis`：先消解问题。当前核心任务：证明百分比信息不能直接缓解额度焦虑。
- `dbs-content`：确认内容形式。首发适合短视频口播 + 产品录屏；长篇技术教程放到 README 或后续视频。
- `dbs-spread`：拆传播心理。核心情绪是“我已经付费，却仍然不敢放心使用”，第一批传播者更可能是 Codex 重度用户、独立开发者、AI 工作流玩家和开源工具爱好者。
- `dbs-resonate`：控制共鸣焦点。一条视频只保留一个核心机制：额度下降只是信号，风险取决于当前使用速度能不能撑到刷新。
- `dbs-hook`：开头优先用个人反差和具体数字。推荐方向是“我买了 Pro，但每周还浪费 60%-70% 的额度”，再引出为什么做这个工具。
- `dbs-benchmark`：竞品部分只服务定位，不展开评测。点到工具类型和差异即可，公开视频不使用未授权竞品截图。
- `dbs-script-flow`：等有实际逐字稿后再用，检查段落衔接、信息密度和口播流畅度。

建议 2-3 分钟结构：

1. 0-10 秒：个人钩子  
   “我已经是 ChatGPT Pro 用户，但我还是会反复看 Codex 额度，而且一看到掉到 90% 或 80% 就开始收着用。”

2. 10-35 秒：具体行为循环  
   反复点开 usage / quota 页面，看到百分比以后没有更安心，反而更不敢用，最后大量额度在刷新前被浪费掉。

3. 35-55 秒：扩大共鸣边界  
   Codex 只是一个入口。Cursor、其他 agent、手机流量这类有限额工具，也可能触发类似的“够不够用”心理负担。表达时保持克制，避免包装成医学问题。

4. 55-80 秒：重新定义真正问题  
   百分比只提供证据，用户真正需要一个工作判断：按现在这个速度，我能不能撑到下一次刷新；如果撑不到，大概什么时候见底；如果能撑到，刷新时还剩多少。

5. 80-115 秒：展示产品  
   展示桌面胶囊、菜单栏状态、展开详情、颜色状态和“能撑到几点/刷新余量/周预测”等关键画面。重点是“扫一眼就知道能不能继续工作”，少讲内部实现。

6. 115-145 秒：市场调研和差异  
   提到 CodexBar、ClaudeBar、`usage`、codexU、onWatch、Quota Float 等当前活跃项目。表达为：已有工具在多 provider、历史分析、账号管理、跨平台和悬浮形态上各有优势；Quota Capsule 选择把默认体验收窄为 Weekly Only、低打断、带置信度的续航判断和未来 24 小时预算。

7. 145-170 秒：开源和分发方式  
   解释这是公开内测，首发走 GitHub + Codex-assisted 安装提示词。强调用户让自己的 Codex clone、测试、构建和启动，敏感信息留在本机。

8. 170-190 秒：后续路线和反馈  
   讲清楚后续会继续做用户引导、历史趋势、Chrome 独立版、更多 agent adapter、签名公证和正式分发。邀请 GitHub Issues、PR、抖音、X、邮箱反馈；如果参与者多，后续可以拉群。

拍摄注意：

- 不要先说“我做了一个工具”，先说痛点。
- 不要把心理学讲成科普课。损失厌恶、稀缺感、心理带宽这些词最多作为一句解释。
- 不要把竞品讲成攻击对象。竞品段只回答“我为什么还要做这个方向”。
- 不要把安装流程讲太久。安装细节交给 README 和 Codex-assisted 提示词。
- 不要承诺正式软件体验。当前定位是公开内测和开源协作。

### 标题候选

- 我做了一个 Codex 额度续航胶囊
- 用 Codex 安装一个 Codex 额度工具
- 每次查 Codex 额度太麻烦，所以我做了 Quota Capsule

### 2-3 分钟口播版

大家好，我是 Bono MA。

最近我自己在高强度使用 Codex 和各种 agent 工具的时候，遇到一个很具体的问题：我经常同时跑好几个任务，也会反复去看 usage 或 quota 页面。但一个简单的百分比其实不够用。比如还剩 40%，这到底安全不安全？按我现在这个速度，能不能撑到下一次刷新？如果撑不到，大概几点会见底？

我后来做了一些调研，也持续跟踪 CodexBar、ClaudeBar、usage、codexU、onWatch、Quota Float 等项目。它们已经证明 quota 可视化和节奏管理是真需求，而且有的在多 provider、历史报告、账号管理、burn-rate 预测或跨平台上做得比我更完整。我的取舍不是再堆一个大 dashboard，而是把问题收窄：我只想在工作时扫一眼，就知道本周额度照这个速度能不能撑到重置，以及未来 24 小时还能放心用多少。

所以我做了 Quota Capsule，中文我暂时叫它“额度胶囊”。

它是一个常驻 Mac 桌面和菜单栏的小胶囊。它会读取本机 Codex 的周额度窗口，把周时间进度、额度已用和最近速度放在一起看，告诉你能否撑到刷新，以及未来 24 小时建议不超过多少。

当前这个内测版本已经支持 macOS 原生悬浮胶囊、菜单栏短状态、详情面板、自动刷新、手动刷新、三语界面、首次引导、统一反馈入口、Codex 整理提示词，以及本地历史和可选的产品改进数据。它默认从本机读取，本机计算。prompt、session、token、cookie、代码内容、文件路径这些都留在你的电脑上。

我这次准备把它开源出来。早期分发方式会比较特别：你可以打开 GitHub 仓库，把 README 里的提示词复制给自己的 Codex，让你的 Codex 帮你 clone、检查环境、构建并启动。这样比直接下载一个陌生的未公证 app 更适合第一批 Codex 用户。

后续我想继续做几件事：第一，把新手引导做得更好；第二，做历史趋势和使用节奏复盘；第三，做独立 Chrome 版本；第四，支持更多 agent provider adapter；第五，等产品更稳定后再补签名、公证、DMG、自动更新这些正式分发能力。

这个项目完全开源。你可以自己 fork、自己改、自己定制。如果你发现 bug，欢迎去 GitHub Issues 提；如果你想支持其他工具，也欢迎提 adapter request 或直接 PR。你也可以通过邮箱、X、抖音联系我。后面如果感兴趣的人比较多，我也可以拉一个群，大家一起讨论怎么把它做得更好。

项目地址放在评论区或简介里。欢迎试用，也欢迎挑毛病。

### 30 秒短版

我做了一个 Codex 额度续航小工具，叫 Quota Capsule，中文暂时叫“额度胶囊”。

它解决的问题很简单：还剩 40% 周额度时，我到底能不能撑到下一次刷新？它会常驻 Mac 桌面和菜单栏，把 Codex 周速度变成初步判断、够用、偏快、可能不够、已用尽、数据暂不可用这些直接判断，并给出未来 24 小时建议。

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
7. 运行 npm run mac:run -- --verify。
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
npm run mac:run -- --verify
```

## 发布前安全审查命令

发布前直接审查 Git 已跟踪的完整文件树：

```bash
npm run audit:repository
```

公开仓库是唯一源码与发布来源；不再生成复制式发布目录。审查必须在 PR 和最终 `main` 提交上分别通过。

## 当前市场调研引用

当前公开、可复核的研究：

- `docs/research/competitor-landscape-2026-07-14.md`
- `docs/distribution/colleague-project-brief.md`

2026-07-01 的旧竞品试用和第三方截图只保留在本机归档，不再作为公开仓库的当前结论。公开视频可以引用新研究中的项目链接和公开 README 事实，但不把未确认授权的第三方截图复制进公开仓库，也不把“当前只返回周窗口”表述为 OpenAI 的永久承诺。
