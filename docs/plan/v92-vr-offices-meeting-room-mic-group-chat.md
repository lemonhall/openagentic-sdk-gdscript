# v92 Plan — VR Offices Meeting Room Mic + Group Chat

## Goal

Add an interactive microphone to Meeting Rooms and open a meeting-room-specific group chat overlay on double click, without affecting existing NPC dialogue flows.

## PRD Trace

- `docs/prd/2026-02-07-vr-offices-meeting-room-mic-group-chat.md`
  - REQ-001, REQ-002, REQ-003, REQ-004, REQ-005

## Scope

- Meeting room decorations:
  - auto-place `mic.glb` on the meeting table (one end, table top)
  - add an always-on “green diamond” interaction indicator
  - add a collider for the meeting table to block NPCs
- Input + UX:
  - double-clicking the mic opens a meeting-room group chat overlay
  - meeting-room overlay reuses DialogueOverlay UI but is a separate instance/controller
  - hide skills UI for meeting-room chat
  - preserve “clear session log” functionality
- Tests:
  - assert mic + indicator + table collision nodes exist
  - assert mic double-click opens overlay and skills UI is hidden

## Non-Scope

- Networking or multi-user chat.
- Meeting room booking/scheduling.
- Audio controls for mic (mute/unmute/voice).
- Chairs/seating placement.

## Acceptance (Hard DoD)

1) Meeting room nodes include stable wrappers:
   - `Decor/Table/Mic` and `Decor/Table/Mic/PickBody` (collision layer `64`)
   - `Decor/Table/Mic/InteractIndicator`
   - `Decor/Table/TableCollision` (`StaticBody3D` with `CollisionShape3D`)
2) Double-clicking the mic opens `UI/MeetingRoomChatOverlay` and:
   - `UI/MeetingRoomChatOverlay/%SkillsButton` is hidden
3) Regression suite remains green:
   - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` → OK

Anti-cheat clause:
- It does not count as done unless the double-click is wired through the same picker path used by other props (raycast pick body), and is covered by an automated test.

## Files

- Add:
  - `docs/prd/2026-02-07-vr-offices-meeting-room-mic-group-chat.md`
  - `docs/plan/v92-index.md`
  - `docs/plan/v92-vr-offices-meeting-room-mic-group-chat.md`
  - `vr_offices/fx/InteractPlumbob.tscn`
  - `vr_offices/fx/InteractPlumbob.gd`
  - `vr_offices/ui/VrOfficesDialogueBlocker.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomChatController.gd`
  - `tests/projects/vr_offices/test_vr_offices_meeting_mic_double_click_opens_overlay.gd`

- Modify:
  - `vr_offices/VrOffices.tscn`
  - `vr_offices/VrOffices.gd`
  - `vr_offices/core/input/VrOfficesClickPicker.gd`
  - `vr_offices/core/input/VrOfficesInputController.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomTableLayout.gd`
  - `tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd`

## Steps (塔山开发循环)

1) **Red:** extend meeting room node test to assert mic wrappers + indicator + table collision.
2) **Red:** add a new test that double-clicking the mic opens the meeting-room overlay.
3) **Green:** implement mic spawn + pick body + indicator; add table collision.
4) **Green:** implement meeting-room chat overlay instance + dedicated controller; hide skills UI.
5) **Refactor:** keep meeting-room chat logic isolated (no changes to `VrOfficesDialogueController` behavior).
6) **Verify:** run VR Offices suite and record evidence in `v92-index`.

## Risks

- Input routing conflicts: meeting-room overlay must not break existing vending/manager-desk double-click behavior.
- UI interference: multiple overlays need correct “dialogue blocker” behavior and close semantics.
- Collision layers: ensure pick-body layers don’t conflict with existing raycast masks.

