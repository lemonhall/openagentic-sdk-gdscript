# v34 — Desk IRC Stability + Disk Logs

## Goal

Fix the observed causal relationship:

> “Desks are green when left alone, but turning on the IRC overlay (or double-clicking a desk) makes them go yellow.”

And add a practical debugging mechanism:

- Persist per-desk IRC logs to disk under `user://` so we can inspect raw traffic and state transitions.

## Scope

In scope:

- Desk IRC config “stability”: desk links should only be refreshed when **desk-relevant** IRC settings change.
- Per-desk debug log file writing (bounded size) and exposing `user://` + absolute path for Windows.

Out of scope:

- Persisting the entire message history as part of world save state.
- UI redesign of the IRC overlay.

## Acceptance

- Closing/opening IRC overlay without changing desk-relevant settings does **not** cause desks to reconnect.
- Desk debug snapshots expose `log_file_user` + `log_file_abs` so the path is discoverable.
- Log file exists after configuring a desk link and contains recent lines.

## Files

- `vr_offices/core/VrOfficesIrcConfig.gd`
- `vr_offices/core/VrOfficesDeskManager.gd`
- `vr_offices/core/VrOfficesDeskIrcLink.gd`
- `tests/projects/vr_offices/test_vr_offices_desk_manager_irc_config_stability.gd`
- `tests/projects/vr_offices/test_vr_offices_desk_irc_disk_log_smoke.gd`

## Steps (塔山开发循环)

### 1) Red

- Add a test proving `set_irc_config()` with only test fields changed does not reconfigure desk links.
- Add a test proving a desk writes an `irc.log` file under `user://`.

### 2) Green

- Normalize desk IRC config to desk-relevant keys and short-circuit refresh when unchanged.
- Add bounded disk logging to `VrOfficesDeskIrcLink`.

### 3) Review

Run:

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_desk_manager_irc_config_stability.gd
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_desk_irc_disk_log_smoke.gd
```

