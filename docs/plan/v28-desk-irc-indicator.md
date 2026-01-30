# v28 — Desk IRC Status Indicator

## Goal

Add a friendly, in-world indicator above each desk to show whether its IRC channel is usable.

## Scope

In scope:

- `StandingDesk` scene adds an `IrcIndicator` node (small plumbob).
- `StandingDesk` script binds to `DeskIrcLink` when present and updates indicator color.
- Preview desks hide the indicator (placement mode).

Out of scope:

- Persisting indicator state to disk (it is derived).

## Acceptance

- `IrcIndicator` exists in `StandingDesk.tscn`.
- When a `DeskIrcLink` child appears and emits `status_changed/ready_changed/error`, the indicator color updates.

## Files

- `vr_offices/furniture/StandingDesk.tscn`
- `vr_offices/furniture/StandingDesk.gd`
- `tests/projects/vr_offices/test_vr_offices_desk_irc_indicator_smoke.gd`

## Steps (塔山开发循环)

### 1) Red

- Add smoke test that creates a desk, injects a fake `DeskIrcLink`, and asserts indicator colors change.

### 2) Green

- Implement indicator nodes + binding logic.

### 3) Review

Run:

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_desk_irc_indicator_smoke.gd
```

