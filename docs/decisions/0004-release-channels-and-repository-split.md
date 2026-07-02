# Decision 0004: 发布渠道与仓库拆分

日期：2026-07-01

## 决策

Quota Capsule 当前采用：

```text
开发分支 + 内测渠道 + 正式发布
```

同时采用 private 工作仓库和 public 发布仓库分离的策略。

公开仓库地址：

```text
https://github.com/Bono12138/codex-quota-capsule
```

## 发布渠道

### 开发分支

开发分支用于工程协作和验证，不作为用户使用版本。

用途：

- 修 bug。
- 做功能开发。
- 跑自动化测试。
- 做本机验证。
- 准备 PR / release candidate。

规则：

- 不直接在 `main` 上堆开发。
- 默认分支前缀使用 `codex/`。
- 开发分支可以包含未完成实现、内部规划和诊断记录。
- 进入内测前必须通过发布检查清单。

### 内测渠道

内测渠道服务 owner 和少量技术朋友。

适合方式：

- Codex-assisted 本地安装。
- 源码构建运行。
- 未公证 ad-hoc zip 包。

内测版可以包含更直接的诊断提示，但仍然不能上传 prompt、session、auth token、cookie、API key 或任何可反推工作内容的数据。

内测阻塞项：

- 读不到数据时误显示安全。
- 额度用完时误显示未知。
- 找不到 Codex CLI 但没有可操作诊断。
- App 不能退出。
- 主胶囊严重挡住工作或拖动抽搐。
- 简中、繁中、英文基础文案缺失。

### 正式发布

正式发布面向公开用户。

第一阶段正式发布仍以 GitHub + Codex-assisted 安装为主，不急于走传统 Mac 下载包路线。分发策略以 `docs/distribution/codex-assisted-distribution-strategy.md` 为准。

正式发布需要：

- 清晰 README。
- INSTALL 中区分 Codex-assisted、手动构建、内部测试包。
- 隐私边界和数据源说明。
- 三语基础 UI。
- GitHub Issues 反馈入口。
- 作者和联系信息。
- release checklist 通过。

正式公开下载包阶段再补：

- Apple Developer ID。
- notarization。
- DMG 或正式 zip。
- app icon。
- release notes。
- 卸载说明。
- 更新策略。

## 本机双版本规则

owner 本机保留两个可并存版本：

| 版本 | App 名称 | Bundle ID | 本地数据目录 | GitHub Issues 默认值 | Analytics endpoint |
| --- | --- | --- | --- | --- | --- |
| 开发版 | `Quota Capsule Dev Local.app` | `com.bono.quota-capsule.dev` | `~/Library/Application Support/Quota Capsule Dev Local` | 不默认指向 public；需要 `QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL` | `QUOTA_CAPSULE_DEV_ANALYTICS_ENDPOINT`，兼容旧 `QUOTA_CAPSULE_ANALYTICS_ENDPOINT` |
| 内测版 | `Quota Capsule Beta.app` | `com.bono.quota-capsule.beta` | `~/Library/Application Support/Quota Capsule Beta` | `https://github.com/Bono12138/codex-quota-capsule/issues` | `QUOTA_CAPSULE_PUBLIC_ANALYTICS_ENDPOINT` |

执行规则：

- 内测版的用户反馈入口必须默认打开 public issues。
- 开发版不能默认打开 public issues；没有配置 private issues URL 时，隐藏 GitHub Issues 按钮。
- 两个版本使用不同的 UserDefaults key 前缀、Application Support 目录和匿名 install id，避免本机状态串用。
- 两个版本使用不同进程名：内测版 `QuotaCapsuleBeta`，开发版 `QuotaCapsuleDevLocal`，允许同时打开做对比。
- 产品事件上报和用户主动提交 issue 是两条通道：analytics endpoint 只收结构化产品事件，GitHub Issues 用于用户主动反馈、bug 和公开需求。

## 修复与发布流转规则

所有代码改动先落在 private 工作仓库源码里。不要只改 public sync 工作树，也不要只改某一个已构建 `.app`。

问题分类：

- P0 / P1 bug：先修复 private 工作仓库，先跑自动化验证，再重建 `Quota Capsule Dev Local.app` 让 owner 本机确认；确认后重建 `Quota Capsule Beta.app`，最后通过 public staging 同步到 public 仓库。
- UI 和功能改动：同样先在 private 工作仓库做，优先用 Dev Local 验证交互和视觉；如果改动进入当前内测范围，再同步 Beta 和 public 仓库。
- 只影响公开文档、README、INSTALL 或 issue 模板的问题：可以直接走 public staging，但仍必须从 private 工作仓库生成 staging，不能在 public 仓库手工漂移。

构建产物管理：

- 根目录 `dist/development/Quota Capsule Dev Local.app` 是 owner 开发版。
- 根目录 `dist/internal-test/Quota Capsule Beta.app` 是当前内测版。
- `artifacts/public-repo-sync/dist/` 只是公开仓库验证时的临时构建产物，验证后应清理，避免 Spotlight 搜到重复的 Beta。

## 仓库拆分

### Private 工作仓库

当前仓库继续作为 private 工作仓库。

保留内容：

- 内部交接文档。
- 产品策略和商业化判断。
- 竞品试用记录。
- 未稳定的实验。
- 尚不适合公开的发布准备。
- private issues 和内部任务。

用途：

- 真实研发。
- owner 决策。
- Codex 协作。
- 内测前准备。

### Public 发布仓库

另建 public 仓库作为对外发布仓库。

只放公开可信内容：

- 源码。
- README。
- INSTALL。
- LICENSE。
- 隐私说明。
- 贡献指南。
- public issue templates。
- release 包或构建说明。

不放：

- 内部交接。
- 未整理的产品策略。
- 私人上下文。
- 敏感诊断。
- 未确认的商业化和传播计划。

## Issue 使用规则

Issue 用于执行跟踪，长期产品判断沉淀在文档里。

Public 仓库 issues：

- 用户 bug。
- 公开 feature request。
- provider adapter request。
- 安装问题。

Private 仓库 issues：

- 内部 P0/P1 开发任务。
- 发布准备。
- 尚未公开的产品判断。
- public 仓库同步任务。

文档负责记录为什么采纳、暂缓或放弃某个方向；issue 负责跟踪谁做、做到哪一步、怎么关闭。

## 和其他项目的关系

Bono MA 可能同时公开多个项目，包括 Quota Capsule 和 DONE / 完事厕所排队系统。

对外账号可以作为个人 builder 入口，后续也能承接 Quota Capsule 之外的项目。Quota Capsule 的关于页和反馈入口可以放：

- Author: Bono MA
- Email: `mmz1218bono@gmail.com`
- X: `https://x.com/starlightsz0`
- Douyin: 火腿肠（`huotuichang439`）
- GitHub: public 仓库确定后填写

如果未来多个项目互相导流，需要保持边界清楚：Quota Capsule 仓库不承载 DONE / 完事的产品实现，最多在作者主页、X、个人介绍或独立项目列表中互相介绍。

抖音后续可以作为主要内容发布和扫码反馈入口。Quota Capsule 可以展示作者抖音二维码，但不能把产品反馈完全绑定到抖音私信，邮箱和 GitHub Issues 仍是第一版可追踪反馈渠道。
