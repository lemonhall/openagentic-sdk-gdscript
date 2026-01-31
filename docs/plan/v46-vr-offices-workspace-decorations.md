# v46 Plan — VR Offices: Workspace Decorations (Office Pack Props)

## Goal

Auto-place a small set of office props in **each** workspace to reduce visual monotony.

## Scope

- Spawn decoration wrapper nodes for each workspace:
  - Wall-hung: Analog clock, Dartboard, Whiteboard, Wall Art 03, Fire Exit Sign-0ywPpb36cyK
  - Floor: File Cabinet, Houseplant-bfLOqIV5uP, Water Cooler, Trashcan Small
- Placement:
  - Use workspace rect (size) to position items against walls / corners.
  - Deterministic (stable across load) based on workspace id.
- Safety:
  - Decorations must not block floor raycasts (mask=1). Disable collisions on decoration models.
- Tests:
  - Extend the existing workspace nodes test to assert decoration nodes exist.

## Non-Goals

- No in-editor placement or runtime “decorate mode”.
- No persistence/editing of decoration layouts.
- No navmesh / pathfinding obstacles.

## Acceptance

- When a workspace node is spawned, it contains:
  - A `Decor` root node under the workspace.
  - Named decoration wrapper nodes for all props listed in Scope.
- Tests:
  - `tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd` asserts the above.
- Collisions:
  - Decoration models have collision disabled (layer/mask = 0) so floor click-to-move is unaffected.

## Files

- Modify:
  - `vr_offices/core/workspaces/VrOfficesWorkspaceSceneBinder.gd`
  - `tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd`
- Add:
  - `vr_offices/core/workspaces/VrOfficesWorkspaceDecorations.gd`
  - `vr_offices/core/props/VrOfficesPropUtils.gd`

## Steps (塔山开发循环)

1) **Red:** extend `test_vr_offices_workspaces_nodes.gd` to require the decoration wrapper nodes.
2) **Red:** run the test to confirm it fails (missing nodes).
3) **Green:** add `VrOfficesWorkspaceDecorations.gd` and call it from `VrOfficesWorkspaceSceneBinder.spawn_node_for`.
4) **Green:** run the test to confirm it passes.
5) **Refactor:** keep the binder minimal; keep decorations isolated; update v46 index evidence.
6) **Verify:** run `scripts/run_godot_tests.sh --suite vr_offices`.

## Risks

- Asset origins vary: use wrapper nodes + simple alignment to avoid severe floating/clipping.
- Collisions from imported props: explicitly disable collisions on decoration instances.
