# Decision 0003: 分发与产品形态计划

日期：2026-07-01

## 决策

Quota Capsule 走三条产品路线，但优先级不是简单的“Chrome 先于 Mac”。

更准确的顺序是：

1. **Mac 本地体验主线优先**：先把创始人自己每天用得爽的版本做出来，默认是桌面悬浮小胶囊，菜单栏作为可选显示状态。
2. **Chrome 独立版同步搭骨架**：Chrome 版本要做成独立产品线，不依赖 Mac app；但第一阶段可以 mock-first，先验证浏览器分发和常驻显示体验。
3. **Windows native 后置**：等 Mac/Chrome 的真实反馈证明需求后，再做 Windows 专属版本。

## 为什么不是“只先做 Chrome”

之前写的 “Chrome first” 容易造成误解。

它真正想表达的是：

- Chrome 版本不要做成 Mac app 的附属品。
- Chrome 版本应当可以独立安装、独立展示、独立试用。
- Chrome 能让我们在 Mac 上开发，同时覆盖 Windows 用户。

但它不应该取代 Mac 本地体验主线。

这个产品最关键的体验是“常驻、好看、扫一眼知道能不能继续干活”。这件事最适合先在 Mac 本地版本上打磨，因为创始人可以每天真实使用、录视频、观察细节。

## 路线定义

### 路线 1：Mac 本地体验主线

目标：

- 让自己先用爽。
- 做出真正常驻、漂亮、低打扰的桌面悬浮小胶囊。
- 提供菜单栏作为可选显示状态。
- 为后续宣传视频提供真实产品体验，而不是网页 demo。

默认显示状态：

- 桌面悬浮小胶囊。

可选显示状态：

- 菜单栏。

### 路线 2：Chrome 独立版

目标：

- 做成独立 Chrome 插件，而不是 Mac app 的配套插件。
- 用同一套核心算法和状态语言。
- 验证跨平台分发是否成立。

第一阶段策略：

- 先 mock-first 搭结构。
- 先验证 toolbar popup、页面 overlay、固定小 badge 哪种体验更适合。
- 等数据源方案明确后，再接真实 quota source。

关键风险：

- Chrome 插件不能天然读取本地 Codex 状态。
- 如果要读本地状态，可能需要 native helper、本地桥接、页面解析，或完全不同的数据源。
- 因此 Chrome 不能阻塞 Mac 本地体验主线。

### 路线 3：Windows native

目标：

- 后续做真正的 Windows 专属体验。

后置原因：

- Windows native 需要处理托盘、置顶、通知、自启动、打包、卸载、信任提示等一整套问题。
- QuotaGem 已经在 Windows 托盘方向做得比较完整。
- 先用 Chrome 覆盖一部分 Windows 用户，等需求明确后再投入 native。

## 结果

- `apps/desktop` 继续作为 Mac/local 体验探索入口。
- 后续新增 `apps/chrome-extension`，但它不是唯一主线。
- 产品文档不再写“Chrome first”这种容易误解的表达。
- MVP 文案应表达为：**Mac 体验优先，Chrome 独立版同步验证，Windows native 后置**。
- 默认 UI 仍然是持久可见的小胶囊，不是 dashboard。

