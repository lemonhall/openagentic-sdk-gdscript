# v99 — VR Offices: Meeting Room invite-only + IRC lifecycle + access control

PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md` (REQ-001 / REQ-012 / REQ-013)

## Problem

The previous “NPC stands near the table” proximity rule is not strict enough: NPCs can wander/clip into the room and appear as participants, and the IRC lifecycle was too tied to opening the mic overlay. We need an invite-only meeting model that can be validated with real E2E tests.

## Scope

- Room lifecycle:
  - When a Meeting Room is created (or loaded), it immediately ensures the host/mic IRC link exists and JOINs the derived channel.
- Invite-only participation:
  - Selected NPC + RMB inside a Meeting Room invites the NPC to that room (pending → meeting-bound on `move_target_reached`) and joins the meeting channel.
  - Normal RMB move outside the room uninvites the NPC (PART + meeting-unbound).
- Access control:
  - Uninvited NPCs cannot enter the Meeting Room bounds; if they do, they are ejected and must not join the meeting channel / meeting state.
- Tests:
  - Update localhost IRC E2E tests to match the lifecycle (host join before any invite).
  - Add a headless regression test for non-invite ejection.

## Non-scope (explicit)

- Complex seating assignment / collision walls / navmesh gating.
- Multi-room concurrent invitation UI beyond RMB.

## Acceptance (Hard DoD)

When running:

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd -TimeoutSec 240 -ExtraArgs --oa-online-tests`

The test must PASS and prove:

1) Meeting Room creation establishes host link + host JOIN (host appears in `NAMES`) **before** any NPC is invited.
2) After inviting 3 NPCs, `NAMES` includes host + all 3 NPC derived nicks.

And offline (headless) regressions must PASS:

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_room_access_ejects_uninvited_npc.gd -TimeoutSec 240`
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240`

## Files

- Add:
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomAccessController.gd`
  - `tests/projects/vr_offices/test_vr_offices_meeting_room_access_ejects_uninvited_npc.gd`
- Modify:
  - `vr_offices/VrOffices.gd`
  - `vr_offices/core/movement/VrOfficesMoveController.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingParticipationController.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomManager.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomStore.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcBridge.gd`
  - `tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd`

## Steps (塔山开发循环)

1) **Red:** update E2E tests to require host auto-join + invite-only; observe failures.
2) **Green:** implement lifecycle callbacks + peek host link, then implement invite/uninvite and access ejection until tests pass.
3) **Verify:** run `-Suite vr_offices` and the localhost E2E tests with `--oa-online-tests`.

