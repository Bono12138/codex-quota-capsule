# Launch Video Materials Requirements

日期：2026-07-05

用途：发给其他 Agent 或人工剪辑者，说明 Quota Capsule 首发宣传视频需要录制、截图和整理哪些素材。

## 输出目标

主视频：抖音 90-120 秒，竖屏 9:16。

辅助素材：

- 30 秒抖音短版。
- X 平台 thread 配图或短视频。
- GitHub README 顶部截图 / GIF。
- 后续 README 和 release 页面可复用的演示素材。

## 安全要求

录屏前先关掉或遮挡：

- prompt 正文。
- session 正文。
- 私有仓库名。
- 私有文件路径。
- token、cookie、API key、auth 状态。
- 用户名之外的本机隐私信息。
- 任何客户、公司、项目内部内容。

展示 Codex 或终端时，只保留必要命令和公开仓库路径。

## 必录素材

### A. 作者口播

用途：视频开头和结尾。

建议画面：

- 半身或近景。
- 安静背景。
- 屏幕上不出现私密信息。

要覆盖的内容：

- “我买了 ChatGPT Pro，但还是会反复看 Codex 额度。”
- “看到 90%、80% 后，我会开始收着用。”
- “最后每周反而浪费很多额度。”
- “我想要的判断是：按现在这个速度，能不能撑到下一次刷新。”

### B. 额度焦虑行为

用途：证明痛点真实。

可以录：

- 鼠标反复打开 usage / quota 页面。
- 看完百分比后回到工作界面。
- 多个 Codex 任务同时运行的安全画面。

注意：

- 只展示动作，不展示敏感内容。
- 真实 usage 数字可以打码。
- 如果没有适合公开的真实页面，用模糊遮罩或 mock 画面表达“反复检查”动作。

### C. Quota Capsule 产品 demo

用途：视频主体和 GitHub README。

必须录：

- 桌面折叠胶囊。
- 展开状态。
- 菜单栏状态。
- “安全 / 注意 / 危险 / 未知”至少 2 种状态。
- 5 小时窗口判断。
- 周预测区域。
- 关于与反馈 / 联系作者入口。

建议录：

- 胶囊拖动。
- 靠边隐藏状态。
- 语言切换入口。
- 首次引导流程。

注意：

- 拖动、调整大小这类视觉操作由人工确认最终效果。
- 如果真实状态不好演示，可以用安全的 mock source 或测试数据录制。

### D. GitHub 安装路径

用途：承接“把提示词交给自己的 Codex”。

必须录：

- GitHub 仓库首页。
- README 顶部。
- Codex-assisted 安装提示词。
- Issues 页面。

可以录：

- 复制安装提示词。
- 粘贴给 Codex。
- Codex 运行 `npm ci`、`npm test`、`npm run build` 的非敏感片段。

注意：

- 不录 private 工作仓库。
- 不录本机绝对路径。
- 不录失败日志里的敏感路径。

### E. 联系和反馈

用途：结尾 CTA。

必须准备：

- GitHub Issues 链接。
- 抖音账号名：火腿肠（`huotuichang439`）。
- X：`https://x.com/starlightsz0`。
- Email：`mmz1218bono@gmail.com`。

抖音二维码可以用于 README 和 App 内，不建议在抖音视频主画面里长时间展示。抖音视频里优先引导“看主页 / 看评论区 / 去 GitHub”。

## GitHub README 素材

README 顶部建议准备：

- 一张胶囊折叠状态截图。
- 一张展开详情截图。
- 一张菜单栏状态截图。
- 一个 8-12 秒 GIF，展示从胶囊到展开详情再到 GitHub 安装提示词。

截图要求：

- 宽度至少 1600px。
- 背景干净。
- 不出现私有项目和本机路径。
- 文件放在 `docs/assets/`，命名建议：
  - `quota-capsule-hero.png`
  - `quota-capsule-expanded.png`
  - `quota-capsule-menu-bar.png`
  - `quota-capsule-demo.gif`

## 竞品段素材

公开视频可以点名：

- QuotaGem
- ClaudeBar
- Codex Quota Viewer
- codex-quota
- opencode-quota

公开素材只用文字列表或自己画的类型图。不要使用未确认授权的第三方截图。

## 交付清单

给剪辑或其他 Agent 的交付物：

- `raw/author-intro.mov`
- `raw/quota-checking-loop.mov`
- `raw/capsule-demo.mov`
- `raw/github-install-flow.mov`
- `raw/feedback-channels.mov`
- `stills/quota-capsule-hero.png`
- `stills/quota-capsule-expanded.png`
- `stills/quota-capsule-menu-bar.png`
- `notes/sensitive-redaction-log.md`

`sensitive-redaction-log.md` 记录哪些片段做过遮挡、裁切或替换，方便发布前复查。

