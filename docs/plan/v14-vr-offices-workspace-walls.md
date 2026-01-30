# v14 Plan — VR Offices Workspaces “Room Walls” (2 Walls, No Occlusion) + Spawn FX

## Goal

Add a “room-like” two-wall visual for each workspace that does not occlude the player view, and animate it on workspace creation.

## Scope

- WorkspaceArea visuals:
  - Keep existing floor plane.
  - Add 4 wall meshes (±X, ±Z) sized to the workspace rect.
  - Only render 2 walls at a time (L-shape) based on camera position quadrant.
  - Fade walls when switching to avoid harsh pops.
- Workspace creation FX:
  - Only on *newly created* workspaces (not on save load / rebuild).
  - Simple “duang” scale/height animation for walls (and slight floor pop).

## Non-Goals

- No doors/windows.
- No collision walls; purely visual.
- No “cutaway” shaders; simple hide/fade behavior.

## Acceptance

- After `WorkspaceArea.configure(rect, ...)`, wall nodes exist and are correctly sized.
- Given camera relative vector `(dx, dz)`:
  - If `dx >= 0` hide `+X` wall, show `-X` wall; else hide `-X`, show `+X`.
  - If `dz >= 0` hide `+Z` wall, show `-Z` wall; else hide `-Z`, show `+Z`.
- On create, `WorkspaceArea.play_spawn_fx()` runs (when not headless).

## Files

- Modify:
  - `vr_offices/workspaces/WorkspaceArea.tscn`
  - `vr_offices/workspaces/WorkspaceArea.gd`
  - `vr_offices/core/VrOfficesWorkspaceManager.gd`
  - `tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd`
- Add:
  - `tests/projects/vr_offices/test_vr_offices_workspace_walls_selection.gd`

## Steps (塔山开发循环)

1) **Red:** add a test for wall selection helper (expected 2 walls for each quadrant).
2) **Red:** extend nodes test to require wall nodes on spawned workspace.
3) **Green:** implement wall nodes + selection helper in `WorkspaceArea.gd`.
4) **Green:** update `WorkspaceArea.tscn` to include wall meshes.
5) **Green:** call `play_spawn_fx()` from `WorkspaceManager.create_workspace()` spawn path (skip headless).
6) **Refactor:** keep strict-mode warnings clean; update v14 index evidence.
7) **Verify:** run Linux headless tests.

## Risks

- Camera detection: use viewport camera and fall back safely if null.
- Visual popping: mitigate with a small fade tween when wall pair changes.

