# v97 index

Goal: Meeting Room chat overlay shows a right-side “参会者” roster so players can immediately confirm which NPCs are in the meeting (and see their IRC nicks).

## Artifacts

- PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md` (REQ-004 / REQ-012 adjacency)
- Plan: `docs/plan/v97-vr-offices-meeting-room-participants-roster-ui.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Roster sidebar exists + populated | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_room_group_chat_broadcast.gd` | todo |
| M2 | Roster updates on join/part | same as M1 | todo |

## Traceability

| Req ID | Plan | Tests / Verify | Evidence |
|---|---|---|---|
| REQ-004 | v97 | `tests/projects/vr_offices/test_vr_offices_meeting_room_group_chat_broadcast.gd` | (pending) |

## Evidence

- (pending)

