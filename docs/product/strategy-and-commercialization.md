# 产品策略与商业化思考

日期：2026-07-01

## 产品判断

Quota Capsule 不是一个普通的“额度显示器”。

它应该是一个 **AI coding 工作的额度续航判断器**：

> 它告诉用户：按照现在这个使用速度，能不能撑到下一次刷新。

产品要把 quota 做成类似“电量 / 续航里程”的感觉，而不是一串需要用户自己心算的账户数字。

## 目标用户

第一批用户：

- Codex 重度用户。
- 经常跑长任务、多开 agent、长时间开发。
- 不愿意频繁点开 dashboard 查看额度。
- 需要快速判断：继续冲、放慢、还是暂停大任务。

第二批用户：

- 使用其他带 quota window 的 agent 产品的人。
- 想给自己工具做 quota adapter 的开发者。
- 希望团队有 AI 使用节奏管理，但不想走向监控/审计的人。

## 产品路线

### 路线 1：Mac 本地体验主线

这是当前最重要的产品主线。

原因：

- 创始人自己可以每天用。
- 能最快发现“常驻桌面到底烦不烦、好不好看、有没有用”。
- 后续拍视频、社交媒体传播，需要一个真实好用的本地体验，而不是网页 demo。

默认形态：

- 桌面悬浮小胶囊。

可选形态：

- 菜单栏。

### 路线 2：Chrome 独立版

Chrome 版本也要做，但它不是替代 Mac 主线。

它的定位是：

- 独立 Chrome 插件。
- 跨平台分发验证。
- 让 Windows 用户在没有 native app 前也能试用部分体验。

第一阶段做法：

- mock-first。
- 先做 toolbar popup、页面 overlay、固定小 badge 的结构。
- 不急着承诺一定能直接读取本地 Codex quota。

关键风险：

- Chrome 插件不能天然读取本机 `~/.codex` 或 `codex app-server`。
- 如果要读真实数据，可能需要 native helper、本地桥接、页面解析，或其他数据源。
- 所以 Chrome 版本应该并行探索，不能拖慢 Mac 本地体验。

### 路线 3：Windows native

Windows native 放后面。

原因：

- Windows 打包、自启动、托盘、通知、置顶、卸载、信任提示都需要额外投入。
- QuotaGem 已经在 Windows 托盘方向做得比较完整。
- 先用 Chrome 覆盖一部分 Windows 用户，等需求更明确后再做 native。

## 默认体验

默认胶囊只回答一个问题：

> 现在这个速度，还能继续干活吗？

状态模型：

| 状态 | 含义 | 示例文案 |
| --- | --- | --- |
| Safe | 当前速度能撑到刷新，并且有明显余量。 | `安全 · 够用到 14:00` |
| Watch | 能撑到刷新，但余量很薄，或者周额度开始有压力。 | `注意 · 能撑到，但余量不多` |
| Danger | 当前速度会在刷新前见底。 | `危险 · 预计 13:00 见底` |
| Unknown | 数据缺失、过期或读取失败。 | `未知 · 暂时读不到额度` |

点开后再解释：

- 时间进度。
- 额度已用。
- 当前 burn rate。
- 刷新时间。
- 如果危险，预计几点见底。
- 如果安全，刷新时预计剩多少。
- 周额度只在必要时显示，不要抢 5 小时窗口的注意力。

## 设计原则

1. 默认是 ambient，不是 dashboard。
2. 先给人话判断，再给数字解释。
3. 颜色只做状态提示，不做大面积装饰。
4. Unknown 必须诚实显示，不能伪装成安全。
5. 用户点开时，要能看懂为什么得出这个判断。
6. MVP 不做账号切换，不做 session manager。
7. UI 必须好看到用户愿意让它常驻桌面。

## 从竞品学到什么

### QuotaGem

值得学：

- Windows 托盘是合理形态。
- compact / expanded 两层结构合理。
- 环形用量图很直观。
- 主题、缩放、阈值、通知设置都很实际。
- `codex app-server` + JSON-RPC 是重要数据源参考。

不要照搬：

- 默认多 provider dashboard 信息密度。
- 只靠 warning/danger threshold 的判断方式。
- 在需求还没证明前过早投入 Windows native。

### ClaudeBar

值得学：

- quota 工具也可以做得漂亮。
- 菜单栏是用户能接受的常驻入口。
- pace-aware 判断是有价值的方向。
- 主题和视觉风格可以增强用户愿意长期打开的意愿。

不要照搬：

- 大渐变、大卡片 dashboard 作为默认体验。
- 过早把产品做成泛 AI provider 监控器。

### Codex Quota Viewer

值得学：

- native Codex 小工具是有需求的。
- stale / read failure 状态必须认真处理。
- `account/rateLimits/read` 是可信的数据源线索。

不要照搬：

- account vault。
- auth switching。
- session manager。
- 以“改 Codex 配置”为第一产品承诺。

### codex-quota

值得学：

- 终端用户喜欢快速键盘工作流。
- mock/demo 模式方便安全试用。

不要照搬：

- TUI 作为大众产品视觉方向。
- 把账号切换做成核心。

### opencode-quota

值得学：

- quota 最好出现在工作发生的地方。
- 同一个数据层可以支持多种 surface：sidebar、toast、status line、command。
- CLI 输出和 JSON 输出对集成很有用。

不要照搬：

- 完全绑定某个工具生态。
- 对普通用户过重的配置式安装。

## 商业化想法

我的判断：**不要一开始就急着商业化收费。**

这个产品早期最重要的是信任和传播，不是立刻收钱。

原因：

- 它读取的是本地 AI 工具状态，用户天然会担心隐私。
- 如果一上来就收费，反而降低试用意愿。
- 开源能帮助我们证明“不偷数据、不改配置、不做账号管理”。
- 这个产品的传播点更像一个好用的小工具，适合先靠开源和视频扩散。

推荐路径：

1. 核心开源：core、source adapter、基础 app 都公开。
2. 用透明隐私边界建立信任。
3. 用真实 Mac 体验拍视频传播。
4. 有真实留存后，再考虑高级功能或团队版。

未来可能收费的方向：

- 团队策略包：共享默认阈值、提示文案、使用节奏建议。
- 偏好同步：同步显示模式、位置、主题，不默认同步原始用量。
- 高级历史分析：个人工作节奏复盘、趋势导出。
- 打包发行服务：签名版、自动更新、稳定渠道。
- 企业/团队定制 adapter：适配内部 agent 工具。

不要早期收费的方向：

- 不要把最基本的“还能不能撑到刷新”锁进付费墙。
- 不要默认上传用户用量。
- 不要把账号管理/session 管理包装成核心卖点。
- 不要把团队功能做成监控/监督工具。

## 对外定位

中文：

> 一个 Codex 额度续航小胶囊：不用心算，直接告诉你现在能不能继续干活。

英文：

> A tiny quota runway capsule for Codex. It tells you whether your current burn rate can survive until reset.

开源开发者版本：

> Codex-first, adapter-friendly quota pacing UI for AI agents.

## 下一步建议

下一阶段围绕五件事做：

1. 只读 `codex app-server` source adapter。
2. `packages/core` 里的续航判断引擎。
3. Mac 桌面悬浮胶囊真实原型。
4. Chrome 独立版 mock-first scaffold。
5. 上线前做一次产品级视觉打磨。

成功标准：

- 用户 1 秒内能看懂状态。
- 读取失败不会显示成安全。
- 点开后能解释判断依据。
- UI 好看到可以常驻桌面。
- repo 清楚区分公开源码、本地状态、隐私数据。

