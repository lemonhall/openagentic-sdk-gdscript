# v81 — VR Offices: Workspace default manager desk + seated manager NPC

## Goal

Implement `docs/prd/2026-02-05-vr-offices-manager-desk-default.md`:

- Workspace auto-gets a manager desk prop (`Desk-ISpMh81QGq.glb`) placed against a wall and facing the workspace center.
- Desk’s internal `chair` node (if present) is pulled back slightly.
- A manager NPC (`character-male-d.glb`) spawns seated at the chair and plays `sit` in a stationary pose.

## Scope

### In scope

- Add manager desk + manager NPC as **workspace defaults** inside `VrOfficesWorkspaceDecorations.decorate_workspace`.
- Add deterministic fitting config for the desk model in `VrOfficesPropUtils`.
- Extend the existing headless workspace-node test to assert the new wrapper nodes exist and basic placement invariants hold.

### Out of scope

- Navmesh / avoidance / collision between NPC and furniture.
- Persisting the manager setup as user-editable desk/NPC entities.

## Design (recommended)

### Approach

- Add two decoration children under each workspace:
  - `Decor/ManagerDesk` (wrapper Node3D): placed near a fixed wall (Z wall), yaw set to face center (no jitter).
  - `Decor/ManagerNpc` (Npc.tscn instance): configured stationary, plays `sit`, positioned at the desk chair if discoverable.
- Keep the feature robust in headless mode:
  - Desk mesh spawn may be skipped in headless; wrapper node still exists.
  - Manager NPC uses placeholder (disable `load_model_on_ready`) in headless tests to avoid importing heavy `.glb`.

### Chair pull-back rule

- If a descendant named `chair` exists under the desk model:
  - Compute whether the chair is on the “center side” or “wall side” of the desk and move it further outward along that axis by a small constant (e.g. `0.25m`).

### Stationary sit

- Add an exported stationary flag + stationary animation name to `vr_offices/npc/Npc.gd`.
- When stationary:
  - Ignore wander and move commands.
  - Keep position fixed and loop the requested animation (prefer `sit`).

## Acceptance

- Creating a workspace results in:
  - `Decor/ManagerDesk` present and placed near a wall, facing inward.
  - `Decor/ManagerNpc` present and stationary.
- No errors in headless mode and existing workspace tests remain green.

## Files

Modify:

- `vr_offices/core/workspaces/VrOfficesWorkspaceDecorations.gd`
- `vr_offices/core/props/VrOfficesPropUtils.gd`
- `vr_offices/npc/Npc.gd`
- `tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd`

Add:

- `docs/prd/2026-02-05-vr-offices-manager-desk-default.md`
- `docs/plan/v81-index.md`
- `docs/plan/v81-vr-offices-manager-desk-default.md`

## Tashan Development Loop Steps (v81)

### Task 1 — Tests (RED)

- Command: `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd`
- Expected: fail with missing `ManagerDesk` / `ManagerNpc` assertions.

### Task 2 — Implementation (GREEN)

- Add manager desk + manager NPC defaults in `VrOfficesWorkspaceDecorations`.
- Add stationary sit support in `Npc.gd`.
- Add desk fitting config in `VrOfficesPropUtils`.

### Task 3 — Verification (still GREEN)

- Command: `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd`
- Optional: `scripts/run_godot_tests.sh --suite vr_offices`

## Evidence

- 2026-02-05
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd` → PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` → PASS (online tests skipped unless `--oa-online-tests`)
