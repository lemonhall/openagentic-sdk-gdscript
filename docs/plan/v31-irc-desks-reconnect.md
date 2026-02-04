# v31 — IRC Desks Reconnect

## Goal

Improve the in-game IRC overlay so desk IRC connectivity is easier to operate and debug:

- Clear “Enabled” gating (desks won’t auto-connect unless enabled).
- Manual “Reconnect all desks” action.

## Scope

In scope:

- Add a Desks-tab button that triggers a reconnect operation.
- Add a safe method on `VrOfficesDeskIrcLink` to explicitly reconnect.
- Add tests.

Out of scope:

- Any persistent per-desk logs/history.
- Per-desk channel override UI (still derived from save/workspace/desk).

## Acceptance

- `SettingsOverlay` Desks tab has a reconnect button and it calls into the desk manager.
- `VrOfficesDeskIrcLink` exposes `reconnect_now()` and it is safe to call in tests when disabled.

## Files

- `vr_offices/ui/SettingsOverlay.tscn`
- `vr_offices/ui/SettingsOverlay.gd`
- `vr_offices/core/VrOfficesDeskManager.gd`
- `vr_offices/core/VrOfficesDeskIrcLink.gd`
- `tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_reconnect.gd` (new)
- `tests/projects/vr_offices/test_vr_offices_desk_irc_link_smoke.gd`

## Steps (塔山开发循环)

### 1) Red

- Add `tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_reconnect.gd`:
  - Instantiate `SettingsOverlay`.
  - Bind it to a fake world + fake desk manager.
  - Press “Reconnect all” and assert the desk manager hook is called.

- Extend `tests/projects/vr_offices/test_vr_offices_desk_irc_link_smoke.gd` to assert `reconnect_now()` exists and is safe when disabled.

### 2) Green

- Implement UI button + signal wiring.
- Add `reconnect_now()` to the desk link and a `reconnect_all_irc_links()` helper on the desk manager.

### 3) Review

Run:

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_reconnect.gd
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_desk_irc_link_smoke.gd
```
