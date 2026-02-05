# VR Offices: Workspace default manager desk + seated manager NPC PRD

## Vision

When a player creates a workspace in `vr_offices`, the workspace should come with a default “manager desk” setup: a desk placed against a wall, facing the room center, and a manager NPC already seated at the desk.

## Requirements

### REQ-001 — Default manager desk prop

- On workspace creation (and on workspace rebuild from saved state), add an office-pack desk model:
  - Asset: `res://assets/office_pack_glb/Desk-ISpMh81QGq.glb`
  - Placed **against a wall** (inside the workspace bounds).
  - Oriented so the desk faces the workspace center (no random yaw jitter).
- Desk scale must be “reasonable” vs existing VR Offices scale conventions (use a deterministic fitting rule).

### REQ-002 — Desk internal chair adjustment (when present)

- If the desk scene contains a descendant node whose name matches `chair` (case-insensitive):
  - Move the chair slightly “pulled back” (increase the chair’s distance from the desk along the desk→chair outward axis).
  - Must be safe if the node does not exist (no errors, no crash).

### REQ-003 — Default manager NPC seated at the desk

- Spawn a manager NPC in the workspace:
  - Model: `res://assets/kenney/mini-characters-1/character-male-d.glb`
  - Plays the `sit` animation in a stationary pose (no wandering / no move-to commands).
  - Positioned at the chair seat when chair node exists; otherwise use a reasonable fallback seat position near the desk.
- In headless/test mode, behavior must remain deterministic and must not require rendering; avoid heavy asset loading where possible.

### REQ-004 — Automated test coverage

- Update/add a headless-safe test that creates a workspace and asserts:
  - The manager desk wrapper node exists and is placed near a wall.
  - The manager NPC node exists and is configured as stationary.

## Non-Goals

- Full furniture collision/avoidance, navmesh, or seated IK alignment.
- Persisting manager desk/NPC as user-editable entities (this slice treats them as workspace defaults).

