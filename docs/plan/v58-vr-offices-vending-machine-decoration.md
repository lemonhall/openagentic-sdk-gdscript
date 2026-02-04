# v58 Plan — VR Offices: Workspace Decorations (Add Vending Machine)

## Goal

When a new workspace is created, auto-place a vending machine prop:

- Placed **against a wall** (not floating in the middle).
- The **front faces the workspace center**.
- The model is **auto-fitted** so it is not comically large/small and remains visible.

## Scope

- Add a new floor decoration wrapper node: `Decor/VendingMachine`
- Spawn model: `res://assets/office_pack_glb/Vending Machine.glb`
- Fit model size by adding an Office Pack fitting rule (target height in meters).
- Deterministic placement based on workspace id (stable across load).

## Non-Goals

- No interaction/physics/collisions for the vending machine.
- No editing/persistence for decoration layout.

## Acceptance

- A spawned workspace node contains `Decor/VendingMachine`.
- `Decor/VendingMachine` is positioned near one wall (within a small margin).
- `Decor/VendingMachine` yaw faces roughly toward the workspace center (inward).
- Tests:
  - `tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd` asserts the wrapper node exists and basic transform constraints.

## Files

- Modify:
  - `vr_offices/core/workspaces/VrOfficesWorkspaceDecorations.gd`
  - `vr_offices/core/props/VrOfficesPropUtils.gd`
  - `tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd`

## Steps (塔山开发循环)

1) **Red:** update `test_vr_offices_workspaces_nodes.gd` to require `Decor/VendingMachine` + basic placement/orientation invariants.
2) **Red:** run `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd` and confirm failure.
3) **Green:** spawn `Vending Machine.glb` in `VrOfficesWorkspaceDecorations.gd` and add fitting config in `VrOfficesPropUtils.gd`.
4) **Green:** rerun the same test and confirm pass.
5) **Refactor:** keep decorations isolated; keep fitting rules centralized in `VrOfficesPropUtils.gd`.
6) **Verify:** run `scripts/run_godot_tests.sh --suite vr_offices`.

## Notes

- Office Pack GLB scales vary; fitting must use computed bounds (target height) rather than trusting import scale.

