# Quota Capsule 项目交接说明

日期：2026-07-01

## 这份文档的用途

这份文档用于从错误上下文切换回 Quota Capsule 的真实项目目录。

当前一部分讨论发生在 `/Users/Zhuanz/Documents/project_done` 这个 DONE / 完事厕所排队系统的 Codex 上下文里，但 Quota Capsule 是独立项目，不应该继续在 DONE 项目里讨论和开发。

后续请在下面这个目录继续：

```text
/Users/Zhuanz/Documents/codex-quota-capsule
```

GitHub 仓库：

```text
https://github.com/Bono12138/codex-quota-capsule
```

## 给下一次 Codex 对话的开场提示词

可以在新对话里直接粘贴：

```text
我们现在继续 Quota Capsule 项目。请先阅读：

1. /Users/Zhuanz/Documents/codex-quota-capsule/README.md
2. /Users/Zhuanz/Documents/codex-quota-capsule/docs/project-handoff-for-next-thread.md
3. /Users/Zhuanz/Documents/codex-quota-capsule/docs/product/acceptance-criteria.md
4. /Users/Zhuanz/Documents/codex-quota-capsule/docs/product/product-ops-feedback-and-copy.md
5. /Users/Zhuanz/Documents/codex-quota-capsule/docs/product/feature-roadmap.md
6. /Users/Zhuanz/Documents/codex-quota-capsule/docs/product/development-plan.md
7. /Users/Zhuanz/Documents/codex-quota-capsule/docs/product/bug-triage-and-release-blockers.md
8. /Users/Zhuanz/Documents/codex-quota-capsule/docs/decisions/0004-release-channels-and-repository-split.md

先不要直接写代码。先确认当前分支、GitHub issue 状态和 P0 bug，再继续实现。
```

## 项目一句话

Quota Capsule 是一个 Codex-first 的桌面额度续航小胶囊。

它不是普通的额度百分比显示器，而是把 Codex 的 quota window 翻译成用户真正关心的问题：

> 按当前速度，我能不能撑到下一次刷新？如果撑不到，大概几点见底？

## 当前产品原则

### 核心体验

默认体验只回答一个问题：

```text
现在这个速度，还能不能继续干活？
```

主界面不追求信息堆叠，不做 dashboard。

### Less Is More

所有新增功能和 UI 变动都必须谨慎。

未经 owner 明确确认，不添加新的主界面功能、不改变默认显示形态、不引入新的视觉组件。

### 不采用的方向

当前明确不采用：

- 环形用量图作为默认功能。
- 阈值设置作为默认能力。

原因：

- 环形图只能表达单个百分比，不能表达“时间进度 vs 额度已用”的核心判断。
- 阈值设置会把判断压力交给用户，而本产品应该自动根据速度和刷新时间判断风险。

## 当前实现状态

项目已经有一个可本地运行的 macOS 原生 app。

主要能力：

- 桌面悬浮胶囊。
- 菜单栏入口。
- 本地只读读取 Codex quota。
- 显示 5 小时窗口、周窗口、刷新时间。
- 根据时间进度和额度已用判断安全、注意、危险、未知。
- 每 60 秒自动刷新。
- 单次刷新失败时保留上次成功数据。
- 胶囊可拖动。
- 菜单栏可以手动刷新、显示/隐藏胶囊、退出。

当前可运行命令：

```bash
cd /Users/Zhuanz/Documents/codex-quota-capsule
npm run mac:run -- --verify
```

生成内部测试包：

```bash
npm run mac:package
```

输出：

```text
dist/Quota-Capsule-macOS.zip
```

## 数据源现状

当前默认数据源：

```text
codex -s read-only -a untrusted app-server
account/rateLimits/read
```

当前只使用脱敏 quota window 字段：

- 5 小时窗口 used percent。
- 5 小时窗口 reset time。
- 周窗口 used percent。
- 周窗口 reset time。

当前不读取：

- prompt 内容。
- session 正文。
- auth token。
- cookie。
- API key。

### 重要限制

当前不是严格实时更新，而是本地轮询：

- 启动时读取一次。
- 后台每 60 秒刷新一次。
- 菜单栏可手动刷新。

未来可研究更完整的数据源：

1. `codex app-server`：当前默认，隐私边界清楚。
2. OAuth `wham/usage`：可能更快、更完整，但需要清楚解释 auth/token 边界。
3. Codex 网页 usage：只能作为可选增强，不能默认启用。
4. `/status` PTY 解析：只适合诊断，不适合后台常规刷新。

## 当前状态体系

用户可见状态：

- `读取中`：启动后或刷新中，且还没有成功数据。
- `安全`：当前速度能撑到刷新，且预计余量较充足。
- `注意`：当前速度能撑到刷新，但预计余量很薄。
- `危险`：当前速度撑不到刷新，或者额度已经用完。
- `未知`：数据缺失、读取失败、短窗口缺失、reset 时间异常，或窗口刚刷新且速度还不稳定。

数据来源状态：

- `实时读取成功`：最近一次刷新成功。
- `显示上次成功数据`：当前刷新失败，但还有上次成功数据可展示。
- `读取失败`：没有可用成功数据。

重要判断：

额度用完时，如果数据源能正常返回，产品应该显示 `危险`，不能显示 `未知`。如果显示 `未知`，说明数据没读到，不代表额度真的用完。

## 已修复的重要问题

### 1. 菜单栏长期显示未知

原因：

- 菜单栏 label 之前拿的是静态 model，不跟随 store 更新。

处理：

- 改成 `MenuBarLabel(store: appDelegate.store)`，使用 `@ObservedObject` 观察 store。

### 2. app 读取 Codex 超时导致未知

原因：

- `codex app-server` 启动时可能做模型/插件同步，8 秒超时过短。

处理：

- 默认超时改成 30 秒。
- 失败时保留上次成功数据。

### 3. 拖动抽搐

原因：

- SwiftUI `DragGesture.translation` 在窗口移动时会重新计算，造成反馈抖动。

处理：

- 改成基于 `NSEvent.mouseLocation` 的全局鼠标坐标差值移动窗口。

### 4. 展开/收起残影

原因：

- SwiftUI transition、弹簧动画、NSPanel 尺寸动画叠加，透明窗口下出现矩形残影。

处理：

- 当前版本改成即时展开/收起，不做弹簧动效。
- 后续如果重新设计动效，必须单独验收。

### 5. 菜单栏“显示/隐藏悬浮胶囊”无效

原因：

- 菜单里通过 `NSApp.delegate as? AppDelegate` 间接查找控制器不稳定。
- 菜单打开时曾经触发 `attach(store:)`，会主动 `show()` 胶囊，容易抵消隐藏动作。

处理：

- 从 `QuotaCapsuleMacApp` 显式传入 `onTogglePanel` 回调。
- 移除菜单打开时自动 show。

## 当前仍需处理的问题

### 1. 朋友电脑读不到 Codex

截图中错误是：

```text
找不到 codex 命令
```

这更像是 Mac 环境找不到 Codex CLI，而不是额度用完导致。

后续需要补诊断：

- `which codex`
- `codex --version`
- app 内展示实际查找过的路径。
- 更友好的安装/修复提示。

### 2. 极端额度状态测试不足

必须补：

- 5 小时额度已用 100%。
- 周额度已用 100%。
- 只有周额度，没有 5 小时窗口。
- Codex CLI 不存在。
- Codex CLI 存在但 app-server 超时。
- Codex 未登录。
- 数据字段缺失。
- reset 时间过期。
- 刷新失败但有上次成功数据。

### 3. 刷新图标有假按钮感

当前胶囊右侧刷新图标看起来像按钮，但它不是独立按钮。

后续必须二选一：

1. 做成真正按钮，并提供刷新中反馈。
2. 去掉按钮感，只作为状态图标。

这属于 UI 行为变更，必须 owner 确认后再做。

### 4. 联系作者和反馈入口

用户希望通过产品认识当前阶段使用 Codex 的用户，收集需求、交朋友、扩大影响力。

候选能力：

- 菜单栏 `关于 Quota Capsule`。
- 菜单栏 `反馈问题 / 提建议`。
- 显示 GitHub 地址。
- 显示作者名字。
- 显示 Gmail 邮箱。

原则：

- 不放在桌面胶囊主界面。
- 不干扰默认额度判断。
- 第一版可以打开 GitHub Issues 或 `mailto:`。

具体名字、邮箱、GitHub 地址需要 owner 明确提供和确认后才能写进产品。

## 文案与语气

后续可以让更新消息/状态文案更丰富，但不能影响核心判断。

候选文案：

- 额度很多、使用很慢：`放心用，不用省着。`
- 刚刷新或几乎没用：`粮仓满着，先放开干。`
- 速度偏快但还能撑到：`悠着点儿，地主家也没余粮。`
- 接近危险：`这速度有点猛，先别开大工程。`
- 已经危险：`快见底了，先收一收。`
- 数据读取失败：`我也想看，但现在没读到。`

这些文案只是候选，不默认上线。上线前需要 owner 确认语气、边界和展示位置。

后续也可探索搞笑语音或轻量音效，但不属于 MVP。

原则：

- 默认关闭。
- 必须可关闭。
- 不打扰工作。
- 不在公共场合造成尴尬。
- 只在明确状态变化或用户主动触发时出现。

## 数据收集与运营

用户观点：

数据收集不是“尽可能少”，而是“只收集对产品改进必要、且能解释清楚的数据”。

原则：

- 提前告知。
- 获取用户同意。
- 开源说明采集项。
- 不上传 prompt、session 正文、auth token、API key、cookie。
- 不上传可反推用户具体工作内容的数据。
- 原始额度数据默认本地保存。
- 如要上传任何用量相关数据，必须单独说明并征得同意。
- 用户可以关闭数据上报。

后续候选运营指标：

- GitHub stars、forks、contributors、issues、PR。
- release 下载量。
- 日活、周活、月活。
- 启动次数。
- 常驻胶囊开启率。
- 展开详情次数。
- 手动刷新次数。
- 刷新失败率。
- 数据源成功率。
- D1 / D7 / D30 留存。
- 用户满意度。
- NPS 推荐意愿。
- 问题上报解决率。

注意：

遥测、问题上报、更新提醒都属于后续功能。不能默认静默上传。

## 分发策略

当前已经有一个分发策略文档：

```text
docs/distribution/codex-assisted-distribution-strategy.md
```

核心思路：

- 早期用户天然是 Codex 用户。
- 第一分发方式可以是 GitHub 开源仓库 + 一段可复制给 Codex 的安装提示词。
- 用户让自己的 Codex 在本机 clone、检查环境、构建和启动。
- 这比陌生 zip 更容易建立信任，也更符合产品定位。

Apple Developer Program 暂时不急：

- 现在产品仍在验证阶段。
- 小范围内测可以继续用源码构建或 ad-hoc 测试包。
- 准备公开发给陌生用户下载时，再考虑 Developer ID 签名和 notarization。

## 工作流现状

### 已有

已经有项目内中文文档：

- `docs/product/acceptance-criteria.md`
- `docs/product/product-ops-feedback-and-copy.md`
- `docs/product/feature-roadmap.md`
- `docs/product/strategy-and-commercialization.md`
- `docs/product/visual-design-direction.md`
- `docs/product/development-plan.md`
- `docs/product/bug-triage-and-release-blockers.md`
- `docs/decisions/0004-release-channels-and-repository-split.md`
- `docs/distribution/public-repo-file-manifest.md`
- `docs/research/realtime-rate-limit-events.md`

当前执行流：

- GitHub Issues 管 bug、开发任务和公开反馈。
- 文档记录需求为什么采纳、暂缓或放弃。
- 不维护重复的 Markdown bug 状态清单。
- 当前采用 `开发分支 + 内测渠道 + 正式发布`。
- 当前计划拆分 private 工作仓库和 public 发布仓库。

### 尚未接入

Spec Kit 尚未正式接入当前仓库。

之前只在临时目录演练过：

```bash
uvx --from git+https://github.com/github/spec-kit.git specify init --here --force --integration codex --integration-options="--skills"
```

演练结果：

- 本机有 `uv` / `uvx`。
- Spec Kit 可以识别 Codex CLI。
- 会生成 `.specify/` 和 `.agents/skills/speckit-*`。

建议：

在新分支接入，不直接在 main 上无脑初始化。

接入后要写中文 constitution，包含：

- 不允许只以 build/test 通过作为完成标准。
- UI 必须覆盖加载、成功、失败、长文本、无数据、刷新中。
- 常驻工具必须验收拖动、点击、动效、遮挡、视觉舒适度。
- AI 完工前必须给出自动化验收和人工验收缺口。
- 涉及动效和手感时，必须请 owner 快速录屏或确认。

## 下一轮建议顺序

推荐下一轮不要直接堆功能，而是按下面顺序：

1. 确认当前开发分支和 issues。
2. 优先做极端状态测试和朋友电脑读不到 Codex 的诊断。
3. 建立简中、繁中、英文三语文案基础。
4. 再做联系作者 / 反馈入口。
5. 准备 public 仓库文件清单和 Codex-assisted 分发文案。
6. 后续再考虑 Spec Kit 或更完整的验收宪法。

推荐优先级：

```text
P0：极端状态测试 + Codex CLI 查找诊断
P1：三语基础界面
P1：联系作者 / 反馈入口
P1：刷新图标语义修正
P2：半隐藏贴边形态
P2：幽默文案体系
P3：语音、遥测、更新提醒
```

## 已确认的 owner 决策

- 采用开发分支、内测渠道、正式发布三层，但用户可见版本只区分内测和正式。
- 当前 private 仓库继续做工作仓库，另建 public 仓库做干净发布仓库。
- Public 仓库需要遵循 `docs/distribution/codex-assisted-distribution-strategy.md`。
- 反馈入口第一版邮箱为主，同时放 GitHub Issues。
- 作者公开信息：
  - Author: Bono MA
  - Gmail: `mmz1218bono@gmail.com`
  - X: `https://x.com/starlightsz0`
  - Douyin: 火腿肠（`huotuichang439`），二维码素材：`docs/assets/douyin-qr.png`
- 第一版上线要支持简中、繁中、英文。
- 繁中不做机械转换，要适配台湾、香港、新加坡等地区的自然用语。
- 刷新按钮结论：当前不承诺严格实时更新，继续使用 60 秒轮询 + 菜单栏手动刷新；主胶囊正常状态不显示假刷新按钮，失败态显示状态图标。
- TikTok 暂不进入产品内入口。
- 未展开胶囊和菜单栏统一显示 `状态 + 5 小时已用百分比`，不显示刷新时间，不提供多个显示模式。
- 周预测进入展开面板低注意力区域，公式必须使用 weekly window 自己的 usedPercent、windowMinutes 和 resetsAt。
- 当前速度只显示倍率，不显示没有语义的进度条。
- 首次用户引导是本轮 P1：说明本机只读、隐私边界、状态颜色、点击胶囊和菜单栏操作；失败时显示诊断。

## 仍需 owner 确认的问题

1. Public 仓库最终名称和 URL。
2. GitHub Issues 公开反馈入口的最终 URL。
3. X bio 和置顶内容是否要由本项目顺手准备。

## 当前验证命令

每次完成后至少跑：

```bash
npm run mac:spec
npm test
npm run build
npm run lint
npm run probe:codex:rate-limits
npm run mac:run -- --verify
```

打包时跑：

```bash
npm run mac:package
codesign --verify --deep --strict --verbose=2 "dist/Quota Capsule.app"
```

`spctl --assess` 当前会 reject，这是预期的，因为内部测试包还没有 Developer ID 公证。

## 重要提醒

- 不要继续在 DONE / 完事厕所排队系统项目里开发 Quota Capsule。
- 不要把环形图、阈值设置、语音、遥测、更新提醒直接当成默认要做。
- 新 UI 和新功能必须先和 owner 确认。
- 任何涉及用户数据上传的设计必须先写清楚采集项、用途、用户告知和关闭方式。
- 动效、拖拽、视觉舒适度不能只靠自动化，需要 owner 人工验收。
