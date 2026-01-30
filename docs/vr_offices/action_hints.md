# Action Hints (VR Offices)

VR Offices uses an on-screen “action hint” overlay for temporary, mode-specific controls (placement modes, tools, etc.).

This is **not** a toast: it stays visible while the mode is active, and disappears when the mode ends.

## UI Component

- Scene: `vr_offices/ui/ActionHintOverlay.tscn`
- Script: `vr_offices/ui/ActionHintOverlay.gd`

API:

- `show_hint(text: String)`
- `hide_hint()`

## Usage Guidelines

- Use action hints for “how to operate” instructions during temporary modes (e.g. desk placement).
- Keep the message short and keyboard/mouse oriented (LMB/RMB/Esc/R…).
- Use toasts for one-off feedback/errors (e.g. “Too many desks”), not for control instructions.

