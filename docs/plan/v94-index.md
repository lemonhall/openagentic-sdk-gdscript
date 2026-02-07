# v94 index

Goal: make “NPC enters meeting” easy to debug and consistent by (1) preventing the move-to waiting timer from re-enabling wandering when meeting-bound, (2) measuring distance-to-table using the actual table collision footprint, and (3) adding a breathing floor indicator around the meeting table to guide placement.

## Artifacts

- PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md`
- Plan: `docs/plan/v94-vr-offices-meeting-zone-indicator.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Meeting-bound suppresses waiting timer | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | done |
| M2 | Meeting distance uses table collision footprint | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | done |
| M3 | Meeting zone breathing indicator around table | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` | done |
| M4 | Full VR Offices regression suite | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` | done |

## Traceability

| Req ID | Plan | Tests / Verify | Evidence |
|---|---|---|---|
| REQ-001 | v94 | `tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | `-Suite vr_offices` OK |
| REQ-011 | v94 | `tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` | `-Suite vr_offices` OK |

## Evidence

- 2026-02-07:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` → OK

