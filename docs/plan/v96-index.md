# v96 index

Goal: stop arguing about “real IRC join” by adding a localhost E2E test that connects to `127.0.0.1:6667` and proves (via IRC `NAMES`) that:

1) the Meeting Room derived channel exists,
2) the host (mic) is in the channel,
3) three NPC participants are in the channel.

## Artifacts

- PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md` (REQ-012)
- Plan: `docs/plan/v96-vr-offices-meeting-room-irc-e2e-localhost.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Localhost IRC E2E test added (gated) | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd -ExtraArgs --oa-online-tests` | done |
| M2 | Meeting host + 3 NPCs really JOIN | same as M1 | done |

## Traceability

| Req ID | Plan | Tests / Verify | Evidence |
|---|---|---|---|
| REQ-012 | v96 | `tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd` | (pending) |

## Evidence

- 2026-02-07:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd -ExtraArgs --oa-online-tests` → PASS
