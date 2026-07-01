# Public 仓库文件清单

日期：2026-07-01

## 目标

Public 仓库是给用户安装、试用、反馈和贡献的干净发布仓库。

它不承载内部交接、私人上下文、未确认商业化判断或尚未整理的实验记录。

## 推荐仓库

待 owner 最终确认仓库名。

候选：

```text
https://github.com/Bono12138/quota-capsule
```

如果未来决定把当前 private 仓库改 public，则需要先清理内部文档和历史暴露风险。

## 必须包含

```text
AGENTS.md
CONTRIBUTING.md
INSTALL.md
LICENSE
Package.swift
README.md
package.json
package-lock.json
tsconfig.base.json
```

```text
.github/ISSUE_TEMPLATE/adapter-request.md
.github/ISSUE_TEMPLATE/bug-report.md
.github/ISSUE_TEMPLATE/feature-request.md
.github/ISSUE_TEMPLATE/install-help.md
.github/workflows/ci.yml
```

```text
Sources/QuotaCapsuleCore/**
Sources/QuotaCapsuleCoreSpec/**
Sources/QuotaCapsuleMac/**
apps/desktop/**
packages/core/**
packages/source-codex/**
scripts/**
script/**
```

```text
docs/decisions/0001-repo-boundary.md
docs/decisions/0002-codex-first-agent-extensible.md
docs/decisions/0003-distribution-and-surface-plan.md
docs/product/brief.md
docs/product/mvp-scope.md
docs/product/acceptance-criteria.md
docs/product/feature-roadmap.md
docs/product/visual-design-direction.md
docs/product/bug-triage-and-release-blockers.md
docs/assets/douyin-qr.png
docs/distribution/codex-assisted-distribution-strategy.md
docs/distribution/public-repo-file-manifest.md
docs/research/data-source-probe.md
```

## 默认不包含

```text
docs/project-handoff-for-next-thread.md
docs/product/strategy-and-commercialization.md
docs/product/product-ops-feedback-and-copy.md
docs/product/development-plan.md
docs/research/competitors/**
```

原因：

- 这些文件包含内部交接、商业化判断、未整理竞品过程或 owner 决策上下文。
- 它们对 private 工作仓库有价值，但对 public 用户不是第一优先级。

## 需要改写后再公开

以下内容可以在 public 仓库出现，但要整理成公开口径：

- 作者介绍。
- 多项目 builder 入口。
- Quota Capsule 和 DONE / 完事等其他项目的互相介绍。
- 抖音二维码和社交账号展示位置。
- 商业化计划。
- 路线图中涉及遥测、历史数据、通知、自动更新的部分。

## Public README 要点

Public README 应优先回答：

1. 这个工具解决什么问题。
2. 它默认只本地读取什么。
3. 它不会读取或上传什么。
4. 怎么让自己的 Codex 安装它。
5. 手动安装怎么做。
6. 遇到 `找不到 codex 命令` 怎么排查。
7. 怎么反馈问题。
8. 作者联系方式和抖音扫码入口。

第一分发方式是 GitHub + Codex-assisted 安装提示词，不是陌生 zip 下载。

## Public issue 规则

Public issues 用于：

- 用户 bug。
- 安装问题。
- provider adapter request。
- 公开 feature request。

Public issues 必须提醒用户不要粘贴：

- token。
- cookie。
- auth 文件。
- API key。
- prompt 正文。
- session 正文。
- 可反推工作内容的原始日志。

## 同步方式

短期可以手工 curated copy。

中期建议增加脚本：

```text
scripts/prepare-public-repo-manifest.ts
```

脚本职责：

- 按 manifest 复制允许公开的文件。
- 检查禁止路径是否混入。
- 检查 `.env`、auth、token、cookie、session 等敏感关键词。
- 输出 public repo staging directory。

在脚本存在前，不要自动同步整个 private 仓库。
