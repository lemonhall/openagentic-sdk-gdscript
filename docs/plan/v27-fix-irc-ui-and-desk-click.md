# v27 — Fix IRC Settings Persistence + Desk Double-Click

## Goal

Address two UX bugs:

1) IRC config changes weren’t persisted if the user didn’t click “Save & Apply”.
2) Desk double-click didn’t work because workspace selection consumed LMB events.

## Scope

- Add explicit Save/Reload buttons, and also auto-save the config when the user uses the Test actions.
- Make workspace selection ignore desk pick hits (layer 8).

## Acceptance

- If user edits host/port and successfully connects from Test, the config is saved and restores after restart.
- Double-clicking a desk opens the IRC overlay and selects the correct desk.

## Files

- `vr_offices/ui/IrcOverlay.tscn`
- `vr_offices/ui/IrcOverlay.gd`
- `vr_offices/core/VrOfficesWorkspaceController.gd`

## Steps (塔山开发循环)

### 1) Red

- Manual: reproduce (edit host, connect, restart: config lost; double-click desk: no response).

### 2) Green

- Auto-save config when Test buttons are used.
- Add explicit Reload button in Settings.
- Skip workspace selection if ray hits desk pick layer.

### 3) Review

- Run focused tests:
  - `tests/test_vr_offices_irc_overlay_smoke.gd`
  - `tests/test_vr_offices_desk_pick_collider.gd`

