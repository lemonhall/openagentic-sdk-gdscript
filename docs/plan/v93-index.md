# v93 index

Goal: Meeting Rooms gain functional “meetings”: NPCs enter a meeting state when commanded near the meeting table, join a per-room channel, and the mic overlay becomes a human group-chat entry that broadcasts to meeting participants (mentions force reply).

## Artifacts

- PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md`
- Plan: `docs/plan/v93-vr-offices-meeting-room-meeting-state-and-irc-channel.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Meeting channel name + mentions parsing | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_channel_names_and_mentions.gd` | done |
| M2 | NPC move-to near table enters/exits meeting state | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | done |
| M3 | Mic overlay message broadcasts to participants | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_room_group_chat_broadcast.gd` | done |
| M4 | Full VR Offices regression suite | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` | done |

## Traceability

| Req ID | Plan | Tests / Verify | Evidence |
|---|---|---|---|
| REQ-001 | v93 | `tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | `-Suite vr_offices` OK |
| REQ-002 | v93 | `tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | `-Suite vr_offices` OK |
| REQ-003 | v93 | `tests/projects/vr_offices/test_vr_offices_meeting_channel_names_and_mentions.gd` | `-Suite vr_offices` OK |
| REQ-004 | v93 | `tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | `-Suite vr_offices` OK |
| REQ-005 | v93 | `tests/projects/vr_offices/test_vr_offices_meeting_room_group_chat_broadcast.gd` | `-Suite vr_offices` OK |
| REQ-006 | v93 | `tests/projects/vr_offices/test_vr_offices_meeting_room_group_chat_broadcast.gd` | `-Suite vr_offices` OK |
| REQ-007 | v93 | `tests/projects/vr_offices/test_vr_offices_meeting_channel_names_and_mentions.gd` | `-Suite vr_offices` OK |
| REQ-010 | v93 | `tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | `-Suite vr_offices` OK |

## Evidence

- 2026-02-07:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` → OK

## Gaps / Follow-ups

- Long-reply transport chunking (REQ-008): implemented in v98 as multi-line IRC PRIVMSG split (see `docs/plan/v98-index.md`).
- Meeting-room observability log (REQ-009): implemented in v98 (see `docs/plan/v98-index.md`).
- Overlay UX roster / refresh: implemented in v97 (see `docs/plan/v97-index.md`).
