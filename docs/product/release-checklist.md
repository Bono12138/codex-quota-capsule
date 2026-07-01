# 发布检查清单

## 当前内部测试包

- 包路径：`dist/Quota-Capsule-macOS.zip`
- App：`Quota Capsule.app`
- Bundle ID：`com.bono.quota-capsule`
- 签名：ad-hoc signing
- 公证：未公证

## 已验证

- `swift run QuotaCapsuleCoreSpec`
- `./script/build_and_run.sh --verify`
- `./script/package_macos.sh`
- `codesign --verify --deep --strict --verbose=2 "dist/Quota Capsule.app"`
- 真实 Codex rate-limit probe 返回 5 小时窗口和周窗口。
- 截图显示悬浮胶囊真实读取 Codex 状态。

## 内部分发口径

这是内部测试版，不要对外宣传为正式发行版。

可以发给同事试用，但要同步说明：

- 需要本机已安装并登录 Codex。
- 第一次打开可能需要右键打开。
- 如被 quarantine 拦截，可执行 `xattr -dr com.apple.quarantine "/Applications/Quota Capsule.app"`。
- 当前不上传数据，不读取 prompt/session 正文，不切换账号。

## 正式公开发布前必须补齐

- Apple Developer ID 签名。
- Notarization。
- DMG 或 pkg 安装器。
- 明确退出、卸载、开机启动设置。
- 持久化快照与隐私说明。
- 崩溃日志和错误诊断最小化设计。
