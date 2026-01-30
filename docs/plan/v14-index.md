# v14 Index — VR Offices Workspaces “Room Walls” (2 Walls, No Occlusion) + Spawn FX

## Vision (v14)

When a workspace is created, it should feel like the player “built a small room” without blocking the view:

- The workspace renders a **two-wall (L-shape) room** around the workspace floor.
- As the camera rotates, the **two walls closest to the camera disappear**, and the **two far walls remain** (always only two walls visible).
- The walls and floor appear with a light “duang” spawn effect when the workspace is created.

## Milestones (facts panel)

1. **Plan:** write an executable v14 plan with tests. (done)
2. **Visuals:** add 4 wall meshes to WorkspaceArea; show only 2 based on camera quadrant. (done)
3. **FX:** play a short spawn animation on create (not on load). (done)
4. **Verify:** tests + headless run. (done)

## Plans (v14)

- `docs/plan/v14-vr-offices-workspace-walls.md`

## Definition of Done (DoD)

- A workspace node contains wall visuals (no collisions required).
- Only 2 walls are visible at a time (L-shape), determined from camera position relative to workspace center:
  - Hide the wall on the camera side for X and Z axes.
  - Show the opposite wall for each axis.
- On workspace creation, walls + floor play a short “duang” animation.
- Tests cover:
  - WorkspaceArea contains expected wall nodes after configure.
  - Wall selection logic is deterministic.

## Verification

- WSL2 + Linux Godot:
  - Follow `AGENTS.md` “Running tests (WSL2 + Linux Godot)”.

## Evidence

- Tests:
  - `tests/test_vr_offices_workspace_walls_selection.gd`
  - `tests/test_vr_offices_workspaces_nodes.gd`
