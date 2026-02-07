# v97 — VR Offices: Meeting Room participants roster UI

PRD adjacency: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md` (REQ-004)

## Problem

Manual playtests can’t easily tell whether NPCs are “in the meeting” (and in the meeting channel). Even when the system works, the UI doesn’t give immediate feedback.

## Scope

- Add a right-side roster panel in the Meeting Room chat overlay titled **“参会者”**.
- Show one row per participant: `DisplayName (irc_nick)` (stable order).
- Keep the roster updated when NPCs join/part the meeting room (in-engine).

## Non-scope (explicit)

- Querying the IRC server for live NAMES in the UI (this would be a separate slice).

## Acceptance (Hard DoD)

- In `test_vr_offices_meeting_room_group_chat_broadcast.gd`, after two NPCs enter meeting state and the mic opens the overlay:
  - the roster panel exists and is visible
  - it contains both participant display names

## Files

- Modify:
  - `vr_offices/ui/DialogueOverlay.tscn`
  - `vr_offices/ui/DialogueOverlay.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomChannelHub.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomChatController.gd`
  - `tests/projects/vr_offices/test_vr_offices_meeting_room_group_chat_broadcast.gd`

## Steps (塔山开发循环)

1) **Red:** extend `test_vr_offices_meeting_room_group_chat_broadcast.gd` to assert roster panel exists + contains Alice/Bob.
2) **Green:** implement roster panel in `DialogueOverlay.tscn` + setters in `DialogueOverlay.gd`.
3) **Green:** emit roster-changed from `VrOfficesMeetingRoomChannelHub.gd` and subscribe from `VrOfficesMeetingRoomChatController.gd` to update the overlay list.
4) **Verify:** run the single test then `-Suite vr_offices`.

