<!--
  v44 — VR Offices: Desk diagnostics copy includes device code + bound NPC
-->

# v44 — IRC Desks: Copy Diagnostics Includes Device Code + Bound NPC

## Vision (this version)

- Make multi-desk debugging faster:
  - Desk diagnostics (the part you Copy) includes:
    - `device_code` (paired machine code)
    - bound NPC identity (`bound_npc_id`, `bound_npc_name`)
- Keep expectations explicit:
  - `device_code` is persistent desk state.
  - bound NPC fields are runtime-only and may be empty.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Desk diagnostics copy | Desks panel copy text includes `device_code` + bound NPC id/name | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_copy_smoke.gd` | done |

## Plan Index

- `docs/plan/v44-irc-desks-copy-device-and-bound-npc.md`

## Evidence

Green:

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_copy_smoke.gd` (PASS)
- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_desk_manager_irc_snapshot_includes_log_path.gd` (PASS)
- `scripts/run_godot_tests.sh --suite vr_offices` (PASS)
