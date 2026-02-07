# v91 Plan — VR Offices Meeting Room Decorations (table + screen + projector)

## Goal

When a Meeting Room is created or loaded, automatically place the meeting table, projector screen, and ceiling projector from `assets/meeting_room/`, using probed model bounds to fit and position them sensibly.

## Scope

- Meeting-room-only decorations module that:
  - probes model bounds (AABB)
  - optionally scales down to fit within meeting room footprint
  - positions table/screen/projector in a conventional layout
- Update meeting room scene spawn to call decorations.
- Extend meeting room node test to assert wrapper nodes exist (works in headless).

## Acceptance

- Meeting room scene includes stable wrapper nodes:
  - `Decor/Table` with `Table.glb` spawned when not headless
  - `Decor/CeilingProjector` with `projector.glb` spawned when not headless
  - `ProjectorScreen` wrapper attached under a wall with `projector screen.glb` spawned when not headless
- Placement adapts to room footprint; models are scaled down if too large.
- Tests pass:
  - `tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd`
  - `scripts/run_godot_tests.ps1 -Suite vr_offices`

## Files

- Add:
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomDecorations.gd`
- Modify:
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingRoomSceneBinder.gd`
  - `tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd`

## Steps (塔山开发循环)

1) **Red:** extend meeting room nodes test to assert decoration wrapper nodes exist.
2) **Green:** add meeting room decorations module + call from scene binder.
3) **Green:** probe bounds and compute placement (center table; screen on short wall; projector on ceiling facing screen).
4) **Refactor:** keep meeting-room-only; avoid growing unrelated files.
5) **Verify:** run `-Suite vr_offices`, record evidence in v91 index.

