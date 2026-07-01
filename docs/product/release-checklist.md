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

## 本轮体验修复验收项

- 状态栏不再长期显示“未知”：启动首轮读取显示“读取中”，读取成功后显示真实状态。
- Codex app-server 读取超时从 8 秒调整为 30 秒，降低 Codex 启动同步导致的假失败。
- 自动刷新改为后台任务循环，每 60 秒尝试刷新一次。
- 单次刷新失败时保留上次成功数据，不把 UI 直接打回未知。
- 胶囊支持拖动位置，拖动算法基于全局鼠标坐标，避免边拖边抽搐。
- 展开/收起暂时采用即时切换，避免透明浮窗出现白色横条或方框残影。
- 详情页显示数据来源、接口、最近成功更新和最近尝试时间。

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
