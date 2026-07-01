# Quota Capsule 安装与使用

## 适用范围

当前包是 macOS 内部测试版：

- 需要 macOS 14 或更新版本。
- 需要本机已经安装并登录 Codex。
- 需要本机能找到 `codex` 命令，常见路径包括 `~/.local/bin/codex`、`/opt/homebrew/bin/codex`、`/usr/local/bin/codex`。
- 当前不是 Apple Developer ID 公证包，所以第一次打开可能被 Gatekeeper 拦截。

## 本机安装

从仓库根目录生成安装包：

```bash
npm run mac:package
```

生成的文件在：

```text
dist/Quota-Capsule-macOS.zip
```

安装方式：

1. 解压 `Quota-Capsule-macOS.zip`。
2. 把 `Quota Capsule.app` 拖到 `/Applications`。
3. 第一次打开时，如果系统提示无法验证开发者，右键点击 app，选择“打开”。

如果仍然被拦截，可以对这个内部测试包执行：

```bash
xattr -dr com.apple.quarantine "/Applications/Quota Capsule.app"
open "/Applications/Quota Capsule.app"
```

## Codex-assisted 安装

早期公开试用优先使用 Codex-assisted 安装，而不是让用户直接下载陌生 zip。

可以把下面这段发给自己的 Codex：

```text
请帮我在本机安装并运行 Quota Capsule：
1. 打开 https://github.com/Bono12138/codex-quota-capsule
2. 先阅读 README、INSTALL.md 和 AGENTS.md。
3. 不要修改我的 Codex 登录状态，不要退出登录，不要重装 Codex。
4. 只允许做本地构建和启动，不要上传我的数据。
5. 检查我本机是否有 Node、npm、Swift、Codex CLI。
6. 如果缺依赖，先告诉我缺什么，不要擅自安装系统级软件。
7. clone 仓库到一个合适的本地目录。
8. 运行 npm install。
9. 运行 npm run mac:run -- --verify。
10. 启动成功后，告诉我如何再次打开它。
```

这条路径适合 Codex 用户、开发者和愿意让本机 Codex 帮忙安装的人。

如果缺少 Node、npm、Swift 或 Codex CLI，Codex 应先说明缺什么，而不是擅自使用 `sudo` 或改动系统级环境。

## 使用方式

启动后会出现两个入口：

- 右上角桌面悬浮小胶囊：默认常驻显示当前状态。
- 菜单栏图标：可立即刷新、显示/隐藏悬浮胶囊、退出应用。

胶囊默认显示：

- `安全 / 注意 / 危险 / 未知`
- 按当前速度能否撑到刷新
- 正常状态保持安静；读取失败时显示状态提示，菜单栏可手动刷新

点击胶囊可展开详情：

- 时间进度
- 额度已用
- 当前速度
- 刷新余量
- 周额度余量
- 刷新时间
- 最近更新时间

胶囊可以拖动位置。当前内部测试版为了避免透明浮窗在展开/收起时出现残影，展开和收起采用即时切换，不做弹簧动效。

## 给同事使用

发给同事这个文件即可：

```text
dist/Quota-Capsule-macOS.zip
```

建议同时附上这段说明：

```text
这是 Quota Capsule 的 macOS 内部测试版。

使用前请确认：
1. 你已经安装并登录 Codex。
2. 你的电脑能在终端运行 codex --version。
3. 解压后把 Quota Capsule.app 拖到 Applications。
4. 第一次打开如被系统拦截，请右键 app -> 打开。
5. 如果仍然打不开，在终端执行：
   xattr -dr com.apple.quarantine "/Applications/Quota Capsule.app"
   open "/Applications/Quota Capsule.app"

这个版本只在本地读取 Codex 的 rate-limit window，不上传数据，不读取 prompt/session 正文，不切换账号。
```

## 隐私边界

应用只调用本地：

```text
codex -s read-only -a untrusted app-server
account/rateLimits/read
```

它只使用 rate-limit window 字段：

- 5 小时窗口已用比例
- 5 小时窗口刷新时间
- 周窗口已用比例
- 周窗口刷新时间

它不会：

- 上传 usage data。
- 读取 prompt 内容。
- 读取 session 正文。
- 读取或保存 auth token。
- 切换 Codex 账号。
- 修改 Codex 配置。

## 故障排查

如果胶囊显示“未知”：

1. 打开终端，确认：

```bash
codex --version
npm run probe:codex:rate-limits
```

2. 如果 `codex --version` 不存在，先修复 Codex CLI 安装或 PATH。
3. 如果 `npm run probe:codex:rate-limits` 返回 error，说明本机 Codex app-server 暂时读不到额度。
4. 退出并重开 Quota Capsule，或从菜单栏点击“立即刷新”。

## 反馈入口

第一版反馈以邮箱和 GitHub Issues 为主：

- Email: `mmz1218bono@gmail.com`
- GitHub Issues: <https://github.com/Bono12138/codex-quota-capsule/issues>
- X: <https://x.com/starlightsz0>
- 抖音：火腿肠（`huotuichang439`）

也可以扫码关注抖音并提交新的意见：

![抖音二维码](docs/assets/douyin-qr.png)

## 当前限制

- 这是 ad-hoc signed 内部测试包，不是已公证正式发行包。
- 目前只做 macOS 版本。
- 目前没有应用版本自动更新；额度数据会每 60 秒自动刷新。
- 目前没有持久化历史页面，历史快照会在后续版本加入。
