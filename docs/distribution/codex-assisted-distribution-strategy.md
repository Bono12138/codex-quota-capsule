# Codex-assisted 分发策略

日期：2026-07-01

## 这份文档记录什么

这份文档只记录 Quota Capsule 的分发、安装、Apple 认证和早期传播策略。

它专门记录分发与安装策略。产品功能继续看：

- `docs/product/feature-roadmap.md`
- `docs/product/strategy-and-commercialization.md`
- `docs/decisions/0003-distribution-and-surface-plan.md`

## 当前判断

Quota Capsule 的早期用户天然是 Codex 用户。

这意味着早期分发不一定要先走传统 Mac app 下载路线。更适合的第一分发方式是：

> GitHub 开源仓库 + 一段可复制给 Codex 的安装提示词。

用户看到社交媒体介绍后，把提示词交给自己的 Codex，让 Codex 在本机完成 clone、检查环境、构建和启动。

这个策略和产品定位更匹配：

- 用户已经有 Codex。
- 产品本身就是解决 Codex 使用节奏和额度判断问题。
- 从源码本机构建比下载陌生未公证 app 更容易建立信任。
- 用户如果遇到构建或启动问题，Codex 可以直接读取错误并处理。
- 传播上也更有记忆点：用 Codex 安装一个 Codex 额度工具。

## Apple Developer Program 的角色

Apple Developer Program 当前价格是 99 美元/年。

它的价值集中在 Mac app 分发的信任基础设施：

- 生成 Developer ID 证书。
- 给 Mac app 做正式签名。
- 提交 Apple notarization 公证。
- 让用户下载后可以更接近正常 app 的方式打开。
- 降低 macOS Gatekeeper 的安全拦截和用户疑虑。

它不能直接提供：

- 宣传流量。
- 用户增长。
- 付款系统。
- 官网。
- 自动更新。
- 开源社区。

所以，99 美元主要购买的是 Mac 认可的开发者身份和分发信任。

官方参考：

- Apple Developer Program：https://developer.apple.com/programs/
- Developer ID：https://developer.apple.com/developer-id/
- Notarization：https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

## 现在是否应该立刻购买 Apple 认证

当前结论：不急。

现在产品仍在验证阶段：

- 产品形态还在调整。
- 桌面胶囊交互还在打磨。
- 数据源策略还没有完全定型。
- 第一批用户更可能是 Codex 用户、开发者或愿意试用开源工具的人。

如果只是发给少量技术同事或熟人内测，可以继续使用：

- GitHub 仓库。
- Codex-assisted 安装提示词。
- 未公证内部测试包 + 明确打开说明。

一旦进入下面阶段，再考虑购买 Apple Developer Program：

- 准备公开发布 GitHub Release 给陌生用户下载。
- 准备发给 10 个以上非技术用户。
- 准备拍视频后让陌生用户直接下载试用。
- 不希望评论区和私信里反复解释“为什么 Mac 说无法验证”。
- 准备做正式 DMG、自动更新、稳定版本渠道。

## 个人账号和公司账号

### 个人账号

适合当前早期阶段。

优点：

- 注册路径更简单。
- 不需要组织身份资料。
- 可以生成 Developer ID 证书。
- 成本同样是 99 美元/年。

不足：

- 签名主体显示个人法定姓名。
- 长期商业化和团队协作的专业感弱一些。

### 公司或组织账号

适合后续正式商业化阶段。

优点：

- 签名主体显示公司或组织名称。
- 对陌生用户更专业。
- 适合团队协作和长期品牌运营。

不足：

- 通常需要 D-U-N-S Number。
- 组织需要被 Apple 认可为 legal entity。
- 注册和身份验证流程更麻烦。

### 深圳个体户是否可用

不能在当前阶段直接假设一定可用。

关键在于 Apple 和 D&B 是否能把该主体识别为可用于 Apple Developer Program 的 legal entity，并生成或匹配 D-U-N-S Number。

后续如果想用个体户主体，应该单独走 Apple / D-U-N-S 查询流程确认。

## 支付问题

Apple Developer Program 不等于支付系统。

如果走 Mac App Store：

- 可以使用 Apple 的付费 app 或 In-App Purchase。
- Apple 处理支付。
- 需要遵守 App Store 审核和支付规则。
- Apple 会抽成。

如果走 GitHub、官网或社交媒体下载：

- Developer ID 只解决签名和公证。
- 支付需要自己解决。
- 可选方案包括 Stripe、Paddle、Lemon Squeezy、支付宝/微信、兑换码、人工授权等。

当前阶段不建议优先考虑支付。更重要的是：

- 产品是否真的解决 Codex 用户的痛点。
- 用户是否愿意长期打开。
- 开源后是否有人愿意试用、反馈、贡献。

## 推荐的早期分发方式

### 第一优先级：GitHub + Codex 安装提示词

适合社交媒体传播、README、开源试用。

公开仓库和 public issues 入口：

```text
https://github.com/Bono12138/codex-quota-capsule
```

公开内测版默认构建 `Quota Capsule Beta.app`，反馈入口默认打开 public GitHub Issues。owner 本机开发版使用 `Quota Capsule Dev Local.app`，需要通过 `QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL` 接 private issues。

推荐文案：

```text
把下面这段发给你的 Codex：

请帮我在本机安装并运行 Quota Capsule：
1. 打开 https://github.com/Bono12138/codex-quota-capsule
2. 先阅读 README、INSTALL.md 和 AGENTS.md。
3. 不要修改我的 Codex 登录状态，不要退出登录，不要重装 Codex。
4. 只允许做本地构建和启动，不要上传我的数据。
5. 检查我本机是否有 Node、npm、Swift、Codex CLI。
6. 如果缺依赖，先告诉我缺什么，不要擅自安装系统级软件。
7. clone 仓库到一个合适的本地目录。
8. 运行 npm ci。
9. 运行 npm test。
10. 运行 npm run build。
11. 运行 swift run QuotaCapsuleCoreSpec。
12. 运行 npm run mac:run:internal-test -- --verify。
13. 启动成功后，告诉我如何再次打开它。
```

这段提示词要强调安全边界：

- 不退出 Codex 登录。
- 不重装 Codex。
- 不修改 Codex auth。
- analytics endpoint 需要用户明确配置。
- 不使用 sudo。
- 只做本地构建和启动。

### 第二优先级：开发者手动安装命令

适合愿意自己操作的用户。

```bash
git clone https://github.com/Bono12138/codex-quota-capsule.git
cd codex-quota-capsule
npm ci
npm run mac:run:internal-test -- --verify
```

### 第三优先级：未公证内部测试包

适合熟人内测，不适合公开传播。

需要附带打开说明：

```text
这是内部测试包。第一次打开如果被 macOS 拦截：
1. 右键点击 Quota Capsule Beta.app，选择“打开”。
2. 如果仍然被拦截，打开 系统设置 -> 隐私与安全性 -> 仍要打开。
3. 如果还不行，再执行：
   xattr -dr com.apple.quarantine "/Applications/Quota Capsule Beta.app"
   open "/Applications/Quota Capsule Beta.app"
```

### 第四优先级：签名公证 DMG

适合产品稳定后公开发布。

需要补齐：

- Apple Developer Program。
- Developer ID Application certificate。
- Hardened Runtime。
- notarization。
- staple。
- DMG 或正式 zip。
- app icon。
- release notes。
- 安装和卸载说明。
- 后续自动更新策略。

## 为什么不把普通用户和开发者用户简单分开

Quota Capsule 的用户会使用 Codex，但其中很多人仍然需要安装流程解释清楚。

他们会使用 Codex，不代表他们理解：

- Xcode Command Line Tools。
- Node/npm。
- SwiftPM。
- PATH。
- Gatekeeper。
- quarantine。
- 本地 app 打包。

所以更准确的用户分层是：

- 会用 Codex、愿意让 Codex 帮自己安装的人。
- 会手动 clone 和构建的人。
- 只想下载并双击打开的人。

早期应该服务第一类和第二类。

第三类用户需要签名公证包，等产品更稳定后再重点服务。

## 当前行动建议

近期优先级：

1. 在 README 增加 Codex-assisted 安装提示词。
2. 在 INSTALL 中区分 Codex-assisted、手动构建、内部测试包三种路径。
3. 保持 GitHub 开源仓库清晰可信。
4. 不急着购买 Apple Developer Program。
5. 当准备公开发布稳定下载包时，再投入 Developer ID 签名、公证和 DMG。

这个策略的核心是：

> 早期先把 Codex 用户的安装路径做顺，传统 Mac app 分发流程等产品更稳定后再加重投入。
