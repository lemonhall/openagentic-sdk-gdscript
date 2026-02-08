# v99 index

Goal: Make Meeting Rooms behave like a real, invite-only meeting with a real IRC lifecycle:

- Meeting Room creation immediately establishes the host/mic IRC connection and JOINs the derived channel.
- NPCs only join the meeting when explicitly invited (RMB into the room), and leave when moved out.
- Uninvited NPCs must not “wander in” (access control + ejection).

## Artifacts

- PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md` (REQ-001 / REQ-012 / REQ-013)
- Plan: `docs/plan/v99-vr-offices-meeting-room-invite-only-and-irc-lifecycle.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Online E2E: host JOIN exists before inviting NPCs | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd -TimeoutSec 240 -ExtraArgs --oa-online-tests` | done |
| M2 | Invite-only: NPC enter/exit meeting state | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd -TimeoutSec 240` | done |
| M3 | Non-invite access control: uninvited NPC ejected | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_room_access_ejects_uninvited_npc.gd -TimeoutSec 240` | done |
| M4 | Full VR Offices regression suite | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` | done |

## Traceability

| Req ID | Plan | Tests / Verify | Evidence |
|---|---|---|---|
| REQ-001 | v99 | `tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` | 2026-02-08 PASS |
| REQ-012 | v99 | `tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd` | 2026-02-08 PASS |
| REQ-013 | v99 | `tests/projects/vr_offices/test_vr_offices_meeting_room_access_ejects_uninvited_npc.gd` | 2026-02-08 PASS |

## Evidence

- 2026-02-08:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd -TimeoutSec 240 -ExtraArgs --oa-online-tests` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_group_chat_localhost.gd -TimeoutSec 240 -ExtraArgs --oa-online-tests` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0

