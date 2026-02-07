# VR Offices: Meeting Room Decorations PRD

## Vision

Meeting Rooms should “look like meeting rooms” immediately after creation. When a Meeting Room is created, the game should automatically place a meeting table, a projector screen, and a ceiling-mounted projector using the assets in `assets/meeting_room/`.

## Requirements

### REQ-001 — Auto-place meeting room props on create/load

- When a Meeting Room is spawned (either newly created or loaded from save), the scene should include:
  - `assets/meeting_room/Table.glb`
  - `assets/meeting_room/projector screen.glb`
  - `assets/meeting_room/projector.glb`
- Placement uses a conventional meeting-room layout:
  - table centered
  - screen attached to a front wall
  - projector hanging from ceiling, facing the screen

### REQ-002 — Probe model bounds before placement

- Before final placement, code must probe each model’s visual bounds (AABB) to:
  - avoid obviously wrong positioning (e.g. table outside the room)
  - scale down models if they would not fit the room footprint with reasonable margins

### REQ-003 — Keep meeting-room code isolated

- Meeting Room decoration logic must live in meeting-room-specific modules (not mixed into workspace decoration code).

### REQ-004 — Regression tests

- Add/adjust tests so that meeting room nodes include stable wrapper nodes for:
  - `Decor/Table`
  - `Decor/CeilingProjector`
  - wall-attached `ProjectorScreen`

## Non-Goals

- Seating/chairs placement.
- Lighting/audio/interactive AV controls.
- New assets or art tweaks.

