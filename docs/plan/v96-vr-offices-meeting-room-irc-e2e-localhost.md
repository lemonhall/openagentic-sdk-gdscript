# v96 — VR Offices: Meeting Room IRC E2E (localhost)

PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md` (REQ-012)

## Problem

Unit tests and in-engine “semantic channel hub” don’t prove that we actually JOIN a real IRC server channel. We need an E2E test that hits a real server at `127.0.0.1:6667` and validates membership from the server’s perspective.

## Scope

- Add a gated E2E test that:
  - spawns a meeting room + 3 NPCs
  - binds them into meeting state (triggering IRC bridge join)
  - uses the in-engine **host IRC link** to issue `NAMES` for the derived meeting channel (avoids extra monitor connections; some servers cap connections per IP)
  - reads `NAMES` and asserts the channel includes:
    - host nick (mic)
    - npc_01, npc_02, npc_03 derived nicks
- Make IRC bridge/link allow networking in headless only when `--oa-online-tests` is present (so CI doesn’t silently open sockets).

## Non-scope (explicit)

- Tests that depend on public internet.
- Testing inbound IRC messages affecting in-engine behavior.

## Acceptance (Hard DoD)

When running:

`pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd -ExtraArgs --oa-online-tests`

The test must PASS and must prove:

1) Meeting Room derived channel is joinable and returns `RPL_ENDOFNAMES (366)`.
2) `NAMES` includes host nick.
3) `NAMES` includes all 3 NPC derived nicks.

If the server is not reachable, the test must FAIL with a clear message (it should not silently skip when `--oa-online-tests` is present).

## Files

- Add:
  - `tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd`
- Modify:
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcBridge.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcLink.gd`
  - `vr_offices/core/irc/VrOfficesIrcNamesRequester.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcBridgeConnections.gd`

## Steps (塔山开发循环)

1) **Red:** write the E2E test first; run it with `--oa-online-tests` and observe it fail (no real join yet).
2) **Green:** fix the root cause (most likely headless gating preventing sockets / join never triggered).
3) **Verify:** rerun the E2E command until it passes reliably.
