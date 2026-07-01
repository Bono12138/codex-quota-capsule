# Decision 0004: 发布渠道与仓库拆分

日期：2026-07-01

## 决策

Quota Capsule 当前采用：

```text
开发分支 + 内测渠道 + 正式发布
```

同时采用 private 工作仓库和 public 发布仓库分离的策略。

## 发布渠道

### 开发分支

开发分支不是给用户使用的版本，而是工程协作和验证环境。

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

Issue 是执行系统，不是长期产品记忆。

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

对外账号可以作为个人 builder 入口，而不是只绑定 Quota Capsule。Quota Capsule 的关于页和反馈入口可以放：

- Author: Bono MA
- Email: `mmz1218bono@gmail.com`
- X: `https://x.com/starlightsz0`
- Douyin: 火腿肠（`huotuichang439`）
- GitHub: public 仓库确定后填写

如果未来多个项目互相导流，需要保持边界清楚：Quota Capsule 仓库不承载 DONE / 完事的产品实现，最多在作者主页、X、个人介绍或独立项目列表中互相介绍。

抖音后续可以作为主要内容发布和扫码反馈入口。Quota Capsule 可以展示作者抖音二维码，但不能把产品反馈完全绑定到抖音私信，邮箱和 GitHub Issues 仍是第一版可追踪反馈渠道。
