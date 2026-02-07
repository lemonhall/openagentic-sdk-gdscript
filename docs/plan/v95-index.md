# v95 index

Goal: close the “manual playtest gap” for Meeting Rooms by (1) making the meeting zone + meeting-bound state visually obvious, and (2) optionally bridging Meeting Room group chat to a real external IRC channel (so humans + NPCs actually join/part and messages are observable outside the engine).

## Artifacts

- PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md`
- Plan: `docs/plan/v95-vr-offices-meeting-room-real-irc-join-and-ux.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Meeting zone indicator visibility hardening | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` | done |
| M2 | Meeting-bound NPC has a persistent visual marker | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | done |
| M3 | Meeting Room IRC link smoke + channel hub wiring | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_room_irc_link_smoke.gd` | done |
|  |  | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_channel_hub_irc_bridge_wiring.gd` |  |
| M4 | Full VR Offices regression suite | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` | done |

## Traceability

| Req ID | Plan | Tests / Verify | Evidence |
|---|---|---|---|
| REQ-001 | v95 | `tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | `-Suite vr_offices` OK |
| REQ-004 | v95 | `tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | `-Suite vr_offices` OK |
| REQ-011 | v95 | `tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` | `-Suite vr_offices` OK |
| REQ-012 | v95 | `tests/projects/vr_offices/test_vr_offices_meeting_room_irc_link_smoke.gd` | `-Suite vr_offices` OK |
| REQ-012 | v95 | `tests/projects/vr_offices/test_vr_offices_meeting_channel_hub_irc_bridge_wiring.gd` | `-Suite vr_offices` OK |

## Evidence

- 2026-02-07:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` → OK

## Gaps / Follow-ups

- REQ-008 (long replies over IRC framing) and REQ-009 (observability/logging) are still out-of-scope for v95 unless they become necessary to stabilize REQ-012.
