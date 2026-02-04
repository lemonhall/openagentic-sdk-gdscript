# v59 Plan — VR Offices: Vending Machine Double-Click Skills Overlay

## Goal

In VR Offices, double-clicking the auto-placed vending machine opens a new overlay panel:

- Same look/feel patterns as `SettingsOverlay` (backdrop + rounded panel + close button + tabs).
- Supports a tabbed layout; for now only one tab named `Skills`.
- Bind the double-click event end-to-end (3D pick -> open overlay).

## Scope

- Add `VendingMachineOverlay` UI:
  - Scene: `vr_offices/ui/VendingMachineOverlay.tscn`
  - Script: `vr_offices/ui/VendingMachineOverlay.gd`
  - UI structure: backdrop + panel + header + close button + `TabContainer` (`Skills`).
- Make vending machine pickable:
  - Attach a `PickBody` `StaticBody3D` + `CollisionShape3D` under the vending wrapper node.
  - Use a dedicated collision layer bit (mask `16`) so it doesn't interfere with floor raycasts.
  - Add the pickable node to group `vr_offices_vending_machine`.
- Input binding:
  - Extend click picker + input controller to route LMB double-click on vending to `VrOffices.open_vending_machine_overlay()`.

## Non-Goals

- No real skills content or persistence yet (UI shell only).
- No physics blocking; pick collider is only for interaction.

## Acceptance

- A test can instantiate `VrOffices.tscn`, create a workspace, double-click the vending machine, and observe `UI/VendingMachineOverlay.visible == true`.
- `scripts/run_godot_tests.sh --suite vr_offices` passes.

## Files

- Add:
  - `vr_offices/ui/VendingMachineOverlay.tscn`
  - `vr_offices/ui/VendingMachineOverlay.gd`
  - `vr_offices/core/props/VrOfficesPickBodyUtils.gd`
  - `tests/projects/vr_offices/test_vr_offices_vending_machine_double_click_opens_overlay.gd`
- Modify:
  - `vr_offices/VrOffices.tscn`
  - `vr_offices/VrOffices.gd`
  - `vr_offices/core/input/VrOfficesClickPicker.gd`
  - `vr_offices/core/input/VrOfficesInputController.gd`
  - `vr_offices/core/workspaces/VrOfficesWorkspaceDecorations.gd`

## Steps (塔山开发循环)

1) **Red:** add `test_vr_offices_vending_machine_double_click_opens_overlay.gd` asserting overlay opens on double click.
2) **Red:** run `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_vending_machine_double_click_opens_overlay.gd` and confirm failure.
3) **Green:** implement:
   - pick body utils + vending pick collider
   - click picker + input controller wiring
   - overlay scene + VrOffices open method
4) **Green:** rerun the test and confirm pass.
5) **Verify:** run `scripts/run_godot_tests.sh --suite vr_offices`.

