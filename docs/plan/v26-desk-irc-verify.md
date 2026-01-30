# v26 — Desk IRC Verification UX

## Goal

Make it easy to verify “this desk is connected/ready” directly in the world by double-clicking it.

## Scope

In scope:

- Add a dedicated pick collider layer for desks (no physical collision).
- Extend input handling to detect double-clicks on desks and open IRC overlay focused on that desk.
- Add `IrcOverlay.open_for_desk(desk_id)` behavior.

Out of scope:

- Persisting desk IRC logs to disk.
- Desktop-level UI polish beyond basic usability.

## Acceptance

- Desk scene has a `StaticBody3D` pick collider on layer `8` (mask `0`).
- Double-clicking a desk opens `IrcOverlay` and selects that desk in the list.

## Files

Modify / add:

- `vr_offices/furniture/StandingDesk.tscn`
- `vr_offices/furniture/StandingDesk.gd`
- `vr_offices/core/VrOfficesInputController.gd`
- `vr_offices/VrOffices.gd`
- `vr_offices/ui/IrcOverlay.gd`
- `tests/test_vr_offices_desk_pick_collider.gd`

## Steps (塔山开发循环)

### 1) TDD Red

- Add `tests/test_vr_offices_desk_pick_collider.gd` expecting the pick collider exists and is on layer `8`.

### 2) TDD Green

- Implement collider in `StandingDesk.tscn` and add the desk to group `vr_offices_desk`.
- On double-click, raycast desks and open IRC overlay focused on that desk.

### 3) Review

Run:

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_vr_offices_desk_pick_collider.gd
```

Then run full test suite.

