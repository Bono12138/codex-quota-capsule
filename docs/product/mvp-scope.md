# MVP 范围

## P0：先把核心体验做出来

- Provider-neutral quota model：额度窗口、刷新时间、已用比例、数据可靠性等核心模型不能绑死 Codex。
- Prediction engine：输出 `safe`、`watch`、`danger`、`unknown`。
- Mock scenarios：覆盖够用、注意、可能用完、校准中、已用尽、数据过期和 source error。
- 只读 Codex 本地 source probe。
- `codex app-server` rate-limit 读取方案验证。
- Mac 桌面悬浮小胶囊原型：先用 mock 数据把真实常驻体验做顺。
- 详情层：解释本周时间进度、额度已用、最近 24 小时实际用量、未来 24 小时建议和刷新时预计余量区间。
- 本地 snapshot 数据模型：先定义字段和隐私边界。
- Chrome 独立版 scaffold：只搭 mock-first 骨架，不阻塞 Mac 主体验。
- Privacy README 和 adapter contribution rules。

## P1：进入真实可用

- 真实 Codex adapter 接入产品壳层：adapter 已能通过只读方式读取 `account/rateLimits/read`，下一步要把它接到 Mac 本地 UI。
- Mac 菜单栏显示状态。
- 悬浮胶囊位置记忆。
- 显示模式设置：悬浮胶囊 / 菜单栏 / 两者都开。
- 本地 snapshot writer：持续记录额度快照。
- 基础历史页：本周用量曲线、速度变化和快照列表。
- Chrome 插件 source feasibility proof：确认到底能否安全、稳定地拿到 quota 数据。
- 中英文状态文案打磨。
- 第一版安装、退出、卸载说明。

## P2：扩展与发布

- Windows always-on-top capsule shell。
- Windows tray icon 和菜单。
- Windows installer。
- Theme packs。
- 历史趋势视图。
- CSV / JSON 导出。
- CLI / JSON 输出。
- 更多 agent adapter。

## 公开发布阻塞项

- Codex source 不能可靠读取。
- 读取失败时仍然显示 safe/green。
- App 不能干净退出。
- 安装后不能清楚卸载。
- 隐私边界没有写清楚。
- UI 还像工程 demo，不适合常驻在用户桌面。
