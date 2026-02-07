# VR Offices: Meeting Rooms PRD

## Vision

VR Offices currently supports creating rectangular **Workspaces** on the floor. We want a second room type: **Meeting Rooms**. Both are “rooms” created by the same rectangle-drag interaction, but Meeting Rooms will later have special behaviors, so they must be maintained as a separate module.

## Requirements

### REQ-001 — Create Meeting Room via rectangle drag

- Player can drag a rectangle on the floor to define a room.
- After the rectangle is defined, player can choose to create either:
  - a Workspace (existing behavior), or
  - a Meeting Room (new).
- Meeting Rooms:
  - have an ID and name
  - spawn a visible floor area (and walls similar to Workspaces for now)
  - do not overlap other rooms (Workspaces or other Meeting Rooms). Border-touch is allowed.

### REQ-002 — Meeting Room context menu + delete

- Right click a Meeting Room to open a context menu (same interaction pattern as Workspaces).
- Menu includes: “Delete meeting room”.
- Deleting removes the Meeting Room from world state and frees its scene node.

### REQ-003 — Persistence

- Meeting Rooms persist in `user://openagentic/saves/<save_id>/vr_offices/state.json` alongside existing world state fields.
- Loading a save restores Meeting Rooms.

### REQ-004 — Regression tests

- Add/adjust automated tests covering:
  - meeting room store/model (placement rules)
  - meeting room nodes spawn/delete
  - meeting room persistence round-trip
  - UI emits signals for “create meeting room” and “delete meeting room”

## Non-Goals

- Meeting Room special features (booking, participants, AV equipment, etc.).
- New visual art assets beyond reusing the current rectangle area style.
- Changing desk placement behavior.

