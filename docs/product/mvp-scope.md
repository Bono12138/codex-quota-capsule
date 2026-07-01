# MVP 范围

## P0：先把核心体验做出来

- Provider-neutral quota model：额度窗口、刷新时间、已用比例、数据可靠性等核心模型不能绑死 Codex。
- Prediction engine：输出 `safe`、`watch`、`danger`、`unknown`。
- Mock scenarios：覆盖 safe、watch、danger、刚刷新、数据过期、source error。
- 只读 Codex 本地 source probe。
- `codex app-server` rate-limit 读取方案验证。
- Mac 桌面悬浮小胶囊原型：先用 mock 数据把真实常驻体验做顺。
- 详情层：解释时间进度、额度已用、预计见底、刷新时预计剩余。
- Chrome 独立版 scaffold：只搭 mock-first 骨架，不阻塞 Mac 主体验。
- Privacy README 和 adapter contribution rules。

## P1：进入真实可用

- 真实 Codex adapter：通过只读方式读取 `account/rateLimits/read`。
- Mac 菜单栏显示状态。
- 悬浮胶囊位置记忆。
- 显示模式设置：悬浮胶囊 / 菜单栏 / 两者都开。
- Chrome 插件 source feasibility proof：确认到底能否安全、稳定地拿到 quota 数据。
- 中英文状态文案打磨。
- 第一版安装、退出、卸载说明。

## P2：扩展与发布

- Windows always-on-top capsule shell。
- Windows tray icon 和菜单。
- Windows installer。
- Theme packs。
- 历史趋势视图。
- 更多 agent adapter。

## 公开发布阻塞项

- Codex source 不能可靠读取。
- 读取失败时仍然显示 safe/green。
- App 不能干净退出。
- 安装后不能清楚卸载。
- 隐私边界没有写清楚。
- UI 还像工程 demo，不适合常驻在用户桌面。

