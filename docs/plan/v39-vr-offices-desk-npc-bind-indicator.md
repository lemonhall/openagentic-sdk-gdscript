# v39 — VR Offices Desk NPC Bind Indicator (Ground Marker)

## Goal

For each `StandingDesk`, add a **ground-level animated indicator** (quest marker style) in front of the desk. When an NPC stands on it, bind the desk to that NPC; when leaving, unbind. The indicator color reflects bound/unbound.

## Scope

In scope:

- Add a `NpcBindIndicator` node under `StandingDesk.tscn` (near floor, in front of the monitor side).
- Use `vr_offices/fx/MoveIndicator.tscn` as the visual (flat, animated ring).
- Add an `Area3D` trigger so we can detect NPC standing/leave.
- Enforce: **one desk ↔ at most one NPC** at a time.
- Hide/suspend the indicator during desk placement preview mode.

Out of scope:

- Persisting bindings to save files (binding is derived from current NPC position).
- Desk-specific job queues / tasks.

## Acceptance

- `StandingDesk.tscn` contains `NpcBindIndicator`.
- When an NPC enters the indicator area:
  - If desk is unbound → binds to that NPC.
  - If already bound to another NPC → ignores.
- When the bound NPC exits → unbinds.
- Indicator color changes between unbound/bound states.

## Files

- Modify: `vr_offices/furniture/StandingDesk.tscn`
- Modify: `vr_offices/furniture/StandingDesk.gd`
- Create: `vr_offices/furniture/DeskNpcBindIndicator.gd`
- Test: `tests/projects/vr_offices/test_vr_offices_desk_npc_bind_indicator_smoke.gd`

## Steps (塔山开发循环)

### 1) Red

- Add `test_vr_offices_desk_npc_bind_indicator_smoke.gd` asserting:
  - Indicator exists and is near the floor.
  - Entering binds (and cannot be stolen).
  - Exiting unbinds.
  - Color changes for bound/unbound.

Run (expect FAIL until implementation exists):

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_desk_npc_bind_indicator_smoke.gd
```

### 2) Green

- Add `NpcBindIndicator` node + wire area signals.
- Implement binding rules and color updates.
- Ensure preview desks suspend/hide the indicator.

Re-run the same command and expect PASS.

