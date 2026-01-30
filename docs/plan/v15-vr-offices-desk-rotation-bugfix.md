# v15 Plan — VR Offices Desk Rotation Placement Bugfix

## Goal

Fix a placement bug where the desk preview can rotate to 180°/270° but the placed desk snaps to only 0°/90°, causing mismatched (sometimes opposite) orientation.

## Root Cause (evidence)

- `VrOfficesWorkspaceController` now allows rotating preview yaw through 0/90/180/270.
- `VrOfficesDeskManager._snap_yaw()` still snaps to **only 0/90** (`posmod(k, 2)`), so 180→0 and 270→90.

## Scope

- Update `VrOfficesDeskManager` yaw snapping and footprint size logic to support 4 orientations.
- Add regression tests.

## Acceptance

- `_snap_yaw(PI)` returns `PI` (not `0`).
- `_snap_yaw(PI*1.5)` returns `PI*1.5` (not `PI*0.5`).
- `add_standing_desk(..., yaw=PI)` stores yaw `PI`.
- `get_standing_desk_footprint_size_xz(yaw=PI*1.5)` swaps X/Z same as 90°.

## Files

- Modify:
  - `vr_offices/core/VrOfficesDeskManager.gd`
  - `tests/projects/vr_offices/test_vr_offices_workspace_desks_model.gd`

## Steps (塔山开发循环)

1) **Red:** extend `tests/projects/vr_offices/test_vr_offices_workspace_desks_model.gd` to assert 4-way yaw snapping and footprint swap for 270°.
2) **Green:** update `_snap_yaw()` to snap to 4 steps, and update `_desk_footprint_size_xz()` swap logic.
3) **Verify:** run Linux headless test(s) for desks model/persistence + smoke.

