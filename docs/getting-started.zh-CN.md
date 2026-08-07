# 第一次使用额度胶囊

不懂 GitHub 也可以安装额度胶囊。

GitHub 是一个保存和发布软件项目的网站。
这个项目的代码、说明、问题反馈和安装包都放在 GitHub。

只想下载额度胶囊，不需要注册 GitHub 账号。

## 下载并安装

安装前请确认：

- 电脑是 macOS 14 或更新版本。
- Codex 已经安装并登录。
- 你访问的是 `Bono12138/codex-quota-capsule` 官方仓库。

安装步骤：

1. 打开 [额度胶囊 v0.3.5-beta.1 发布页](https://github.com/Bono12138/codex-quota-capsule/releases/tag/v0.3.5-beta.1)。
2. 找到页面里的 **Assets** 区域。
3. 下载 `Quota-Capsule-Beta-macOS.zip`。
4. 不要下载 `Source code (zip)`。那是给开发者看的源代码，不能直接当应用使用。
5. 双击下载的 ZIP 文件，将它解压。
6. 把 `Quota Capsule Beta.app` 拖进“应用程序”文件夹。
7. 在“应用程序”里打开 `Quota Capsule Beta.app`。

启动后，桌面会出现一个额度胶囊。
菜单栏也会出现额度胶囊图标。

## macOS 阻止首次打开怎么办

当前 Beta 还没有经过 Apple 公证。
macOS 可能提示无法验证开发者。

请先确认应用来自本项目的官方发布页。
确认来源后，按照 Apple 当前的处理方式操作：

1. 先尝试打开一次应用。
2. 打开“系统设置”。
3. 进入“隐私与安全性”。
4. 向下滚动到“安全性”。
5. 点击与额度胶囊对应的“仍要打开”。
6. 再次确认“打开”。

如果 macOS 明确提示应用已损坏或会损害电脑，请停止安装并提交反馈。
不要绕过这类安全警告。

Apple 官方说明：[安全地打开 Mac 上的 App](https://support.apple.com/zh-cn/102445)。

## GitHub 账号有什么用

下载公开安装包不需要账号。

遇到下面这些情况，才需要注册：

- 给项目点 Star，方便以后找到。
- 在 Issues 里报告问题。
- 参与代码或文档贡献。

注册步骤：

1. 打开 [GitHub 注册页面](https://github.com/signup)。
2. 使用邮箱注册，或者选择 Google、Apple 登录。
3. 按页面提示设置用户名。
4. 完成邮箱验证。
5. 注册完成后，建议开启双重身份验证。

GitHub 官方说明：[创建个人账号](https://docs.github.com/zh/account-and-profile/how-tos/personal-account-management/creating-an-account-on-github)。

## 报告问题

1. 登录 GitHub。
2. 打开项目的 [Issues 页面](https://github.com/Bono12138/codex-quota-capsule/issues)。
3. 点击 **New issue**。
4. 写清楚你看到的现象、发生时间、额度胶囊版本和 macOS 版本。
5. 截图可以帮助定位问题，但请先遮住账号、项目名称和其他私人信息。

请不要上传 Codex token、cookie、聊天内容、代码、私有文件路径或账号凭据。

不想注册 GitHub，也可以发送邮件到 `mmz1218bono@gmail.com`。

## GitHub 页面里几个常见词

| 页面文字 | 普通用户需要知道什么 |
| --- | --- |
| Repository | 项目主页，也就是这个软件在 GitHub 上的家。 |
| Release | 已经打包好的发布版本。普通用户从这里下载安装包。 |
| Assets | 某个 Release 可以下载的文件。 |
| Source code | 程序源代码。普通用户不用下载。 |
| Issues | 报告 Bug、提出建议和查看已知问题的地方。 |
| Star | 收藏并支持这个项目。 |

GitHub 官方对 Release 的解释：[关于发布版本](https://docs.github.com/zh/repositories/releasing-projects-on-github/about-releases)。
