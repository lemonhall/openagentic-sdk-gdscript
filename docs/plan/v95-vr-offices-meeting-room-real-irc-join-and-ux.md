# v95 — VR Offices: Meeting Room real IRC join + meeting UX clarity

PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md`

## Problem

Even though v93/v94 added meeting state + zone indicator + in-engine “channel hub”, manual playtests can still feel like “nothing happened”:

- The meeting zone indicator can be too subtle (or visually lost against the floor).
- Meeting-bound NPCs have no persistent “I’m in a meeting” marker.
- The meeting room “IRC channel” is currently semantic-only (in-engine hub) and does not join a real external IRC server, so external observers/tools can’t see an actual JOIN/PART/PRIVMSG stream.

## Scope

- Make the meeting zone indicator more visible and enforce its shader params via tests.
- Add a persistent meeting-bound marker on NPCs (visible even when not selected).
- Add an optional external IRC bridge for meeting rooms:
  - When enabled (non-headless + IRC config present), create a real IRC client for the meeting room host and for each meeting participant NPC.
  - Join/part the derived meeting room channel.
  - Mirror human messages (mic overlay) and NPC replies to the external IRC channel.

## Non-scope (explicit)

- Roster UI / click-to-mention.
- External IRC inbound messages driving in-engine behavior (observer-only for v95).
- Any online/e2e tests that require a real IRC server.

## Acceptance (Hard DoD)

1) Meeting zone indicator:
   - `Decor/MeetingZoneIndicator` exists for every meeting room and has a `ShaderMaterial` with explicitly-set visibility parameters (`ring_alpha`, `fill_alpha`, `pulse_max`) above a minimum threshold.
2) NPC meeting marker:
   - When an NPC is meeting-bound, a visible marker node exists and is `visible == true`.
   - When the NPC exits meeting state, that marker is hidden.
3) External IRC join (optional):
   - If IRC is configured (host + port) and we are not headless, opening a meeting room chat and having participants bound results in:
     - a host client configured with a stable nick and a derived meeting room channel name
     - per-NPC clients configured with derived nicks (NICKLEN respected) that attempt to join the same channel
   - The meeting chat overlay title includes the derived channel name (so manual playtests can easily join/observe).
   - Headless tests do not open sockets; wiring is verified via smoke tests and simulated IRC messages.

## Files

- Modify:
  - `vr_offices/fx/MeetingZoneIndicator.gd`
  - `vr_offices/npc/Npc.tscn`
  - `vr_offices/npc/Npc.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomChannelHub.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomChatController.gd`
  - `vr_offices/VrOffices.gd`
- Add:
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcLink.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcBridge.gd`
  - `tests/projects/vr_offices/test_vr_offices_meeting_room_irc_link_smoke.gd`
  - `tests/projects/vr_offices/test_vr_offices_meeting_channel_hub_irc_bridge_wiring.gd`

## Steps (塔山开发循环)

### Slice 1 — Meeting zone indicator visibility (Red → Green → Refactor)

1) **Red:** Extend `tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` to assert visibility shader params are explicitly set (and above thresholds).
2) **Green:** Update `vr_offices/fx/MeetingZoneIndicator.gd` to set the shader params during `configure()`.
3) **Verify:** `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd`

### Slice 2 — NPC meeting marker (Red → Green → Refactor)

1) **Red:** Extend `tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` to assert a meeting marker toggles visibility on bind/unbind.
2) **Green:** Add a `MeetingRing` node to `vr_offices/npc/Npc.tscn` and wire it in `vr_offices/npc/Npc.gd`.
3) **Verify:** `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd`

### Slice 3 — External IRC join bridge (Red → Green → Refactor)

1) **Red:** Add `tests/projects/vr_offices/test_vr_offices_meeting_room_irc_link_smoke.gd` (patterned after the desk IRC smoke test).
2) **Green:** Implement `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcLink.gd`:
   - safe in headless (no sockets)
   - configurable nick + channel
   - becomes ready on simulated JOIN matching desired channel
3) **Green:** Implement `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcBridge.gd` and wire it into:
   - `VrOfficesMeetingRoomChannelHub` (join/part + mirror messages)
   - `VrOffices.gd` (create bridge, pass IRC config, update on config changes)
4) **Verify:**
   - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_room_irc_link_smoke.gd`
   - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_channel_hub_irc_bridge_wiring.gd`
   - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices`
