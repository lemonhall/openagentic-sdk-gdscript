# v32 — IRC Auto-Connect + Desk Ready Detection

## Goal

Make IRC desks “just work”:

- No `Enabled` toggle: if host is set and saved, desks connect.
- Desk readiness becomes accurate: mark ready on JOIN even when the channel is in `trailing` (e.g. `JOIN :#channel`).

## Scope

In scope:

- Remove Enabled UI and config key usage (keep backward-compatible behavior for old saves).
- Desk manager attaches links whenever IRC host is configured (host non-empty).
- Fix desk join detection (`params[0]` vs `trailing`).
- Update tests accordingly.

Out of scope:

- Sharing a single IRC connection across all desks (each desk still maintains its own connection).
- Persisting per-desk logs.

## Acceptance

- After saving host/port, desks spawn/connect automatically on startup.
- `VrOfficesDeskIrcLink` becomes ready on a JOIN message where `msg.trailing == desired_channel`.
- All related tests pass.

## Files

- `vr_offices/ui/IrcOverlay.tscn`
- `vr_offices/ui/IrcOverlay.gd`
- `vr_offices/core/VrOfficesIrcSettings.gd`
- `vr_offices/core/VrOfficesIrcConfig.gd`
- `vr_offices/core/VrOfficesDeskManager.gd`
- `vr_offices/core/VrOfficesDeskIrcLink.gd`
- `tests/projects/vr_offices/test_vr_offices_irc_overlay_autosave.gd`
- `tests/projects/vr_offices/test_vr_offices_irc_settings_persistence.gd`
- `tests/projects/vr_offices/test_vr_offices_desk_irc_link_smoke.gd`

## Steps (塔山开发循环)

### 1) Red

- Update tests to reflect removal of `enabled`.
- Add/extend a test asserting desk join readiness when JOIN uses `trailing`.

### 2) Green

- Remove `Enabled` field and gating logic.
- Fix JOIN readiness detection.

### 3) Review

Run:

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_desk_irc_link_smoke.gd
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_irc_overlay_autosave.gd
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_irc_settings_persistence.gd
```

