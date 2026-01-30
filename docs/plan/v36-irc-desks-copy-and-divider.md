# v36 — IRC Desks: Copy + Divider

## Goal

Improve debugging ergonomics in `IRC → Desks`:

- The top diagnostics block is not selectable (Label), so add a one-click Copy action.
- Add a divider between the diagnostics block (desk/ws/channel/status/ready/log) and the raw IRC log viewer.

## Scope

In scope:

- `IrcOverlay.tscn` layout tweaks in Desks tab.
- `IrcOverlay.gd` copy-to-clipboard wiring.
- A smoke test ensuring nodes exist and selection enables Copy.

Out of scope:

- Persisting more data or redesigning the entire overlay.

## Acceptance

- A `Copy` button exists, is disabled when nothing is selected, and becomes enabled after selecting a desk.
- The details panel includes a divider control between the info and log widgets.

## Files

- `vr_offices/ui/IrcOverlay.tscn`
- `vr_offices/ui/IrcOverlay.gd`
- `tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_copy_smoke.gd`

## Steps (塔山开发循环)

### 1) Red

- Add a smoke test that fails if Copy button/divider is missing.

### 2) Green

- Add the UI nodes and wire the copy action.

### 3) Review

Run:

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_copy_smoke.gd
```

