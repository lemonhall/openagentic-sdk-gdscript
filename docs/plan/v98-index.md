# v98 index

Goal: Make Meeting Rooms feel like a real public group chat:

- NPCs get explicit meeting context (who/where/what) on each turn.
- Public messages are observable (persistent event log).
- Long IRC messages are not silently truncated (split into multiple PRIVMSG lines).
- Add an online E2E test against `127.0.0.1:6667` proving the above.

## Artifacts

- PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md` (REQ-008 / REQ-009)
- Plan: `docs/plan/v98-vr-offices-meeting-room-group-chat-context-logs-and-irc-long-messages.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Online E2E: JOIN + host/npc PRIVMSG visible | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_group_chat_localhost.gd -TimeoutSec 240 -ExtraArgs --oa-online-tests` | done |
| M2 | Long reply not truncated | same as M1 | done |
| M3 | Meeting-room event log written | same as M1 | done |
| M4 | Full VR Offices regression suite | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` | done |

## Traceability

| Req ID | Plan | Tests / Verify | Evidence |
|---|---|---|---|
| REQ-008 | v98 | `tests/projects/vr_offices/test_e2e_meeting_room_irc_group_chat_localhost.gd` | 2026-02-07 PASS |
| REQ-009 | v98 | `tests/projects/vr_offices/test_e2e_meeting_room_irc_group_chat_localhost.gd` | 2026-02-07 PASS |

## Evidence

- 2026-02-07:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_group_chat_localhost.gd -TimeoutSec 240 -ExtraArgs --oa-online-tests` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` → EXIT=0

