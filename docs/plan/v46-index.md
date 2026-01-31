<!--
  v46 — VR Offices: Workspace Decorations (Office Pack props)
-->

# v46 — VR Offices: Workspace Decorations (Office Pack Props)

## Vision (this version)

- Make each workspace feel less empty by auto-placing a small set of office props:
  - Wall-hung: analog clock, dartboard, whiteboard, wall art, fire exit sign.
  - Floor: file cabinet (against wall), houseplant (corner), water cooler (corner), trashcan (near desk area).
- Keep interactions stable:
  - Decorations must not interfere with floor click-to-move raycasts (collision layer 1).

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Workspace decorations spawn | Newly created/spawned workspace nodes include decoration wrapper nodes (headless-safe) | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd` | done |

## Plan Index

- `docs/plan/v46-vr-offices-workspace-decorations.md`

## Evidence

Green:

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd` (PASS)
- `scripts/run_godot_tests.sh --suite vr_offices` (PASS)
