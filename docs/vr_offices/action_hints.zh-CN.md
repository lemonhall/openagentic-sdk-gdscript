# 操作提示（VR Offices）

VR Offices 使用一种“操作提示（action hint）”的 UI 组件来显示临时模式（摆放、工具操作等）的控制方式。

它**不是 toast**：会在模式持续期间一直显示，结束后自动消失。

## UI 组件

- 场景：`vr_offices/ui/ActionHintOverlay.tscn`
- 脚本：`vr_offices/ui/ActionHintOverlay.gd`

API：

- `show_hint(text: String)`
- `hide_hint()`

## 使用建议

- 进入临时操作模式时（例如办公桌摆放），用操作提示展示“怎么操作”。
- 文案保持简短，聚焦 LMB/RMB/Esc/R 等按键。
- Toast 更适合一次性的反馈/错误提示（例如“桌子太多了”），不要用来替代操作提示。

