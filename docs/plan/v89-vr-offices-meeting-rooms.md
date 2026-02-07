# v89 Plan — VR Offices Meeting Rooms (create + delete + persistence)

## Goal

Add a new room type: Meeting Room. Players can drag a rectangle to define a room footprint, then create either a Workspace (existing) or a Meeting Room (new). Meeting Rooms support context-menu delete and persist in VR Offices world state.

## Scope

- New Meeting Room module (store/manager/scene binder + area scene).
- Extend rectangle-create UX to support Meeting Rooms without breaking Workspaces.
- Add Meeting Room context menu delete (mirrors Workspace context menu behavior).
- Persist Meeting Rooms in `vr_offices/state.json`.
- Add regression tests.

## Acceptance

- Rectangle drag shows create popup where user can choose Workspace vs Meeting Room.
- Creating a Meeting Room spawns an in-world area node in group `vr_offices_meeting_room`.
- Meeting Rooms can be deleted via right-click context menu.
- Meeting Rooms persist across save/load.
- Existing Workspace create/delete/desk placement tests remain green.

## Files

- Add:
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomStore.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomSceneBinder.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomManager.gd`
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomController.gd`
  - `vr_offices/meeting_rooms/MeetingRoomArea.tscn`
  - `vr_offices/meeting_rooms/MeetingRoomArea.gd`
  - `tests/projects/vr_offices/test_vr_offices_meeting_rooms_model.gd`
  - `tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd`
  - `tests/projects/vr_offices/test_vr_offices_meeting_rooms_persistence.gd`

- Modify:
  - `vr_offices/VrOffices.tscn`
  - `vr_offices/VrOffices.gd`
  - `vr_offices/core/save/VrOfficesSaveController.gd`
  - `vr_offices/core/state/VrOfficesWorldState.gd`
  - `vr_offices/core/input/VrOfficesInputController.gd`
  - `vr_offices/core/workspaces/VrOfficesWorkspaceController.gd`
  - `vr_offices/core/workspaces/VrOfficesWorkspaceSelectionController.gd` (or replace with a shared controller)
  - `vr_offices/ui/WorkspaceOverlay.tscn`
  - `vr_offices/ui/WorkspaceOverlay.gd`
  - `tests/projects/vr_offices/test_vr_offices_workspace_overlay.gd`

## Steps (塔山开发循环)

1) **Red:** add meeting room model/store tests (placement, border-touch allowed, overlap rejected).
2) **Red:** add meeting room persistence round-trip test (world state + manager reload).
3) **Red:** extend overlay test to assert meeting room create/delete signals.
4) **Green:** implement Meeting Room store/manager + scene binder + area scene; make model tests pass.
5) **Green:** wire persistence (save/load) and make persistence tests pass.
6) **Green:** wire UX:
   - rectangle create supports Meeting Room
   - context menu delete for Meeting Room
7) **Refactor:** keep meeting room logic isolated in its own module; keep warnings clean.
8) **Verify:** run VR Offices test suite; record evidence in v89 index.

## Risks

- UI/back-compat: extending the existing WorkspaceOverlay must not break existing workspace flows/tests.
- State schema drift: avoid breaking older saves; keep new fields optional on load.

