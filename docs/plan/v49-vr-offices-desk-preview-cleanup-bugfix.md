# v49 Plan — VR Offices Desk Preview Cleanup Bugfix

## Goal

Fix desk placement cleanup so ending placement (place/cancel) never attempts to `free()` a `RefCounted`, and always cleans up the temporary desk preview node.

## Root Cause (evidence)

- Stack trace points to `VrOfficesWorkspaceDeskPlacementController.gd:62` `end_placement()` calling `_preview.call("free")`.
- `_preview` is a `RefCounted` instance of `VrOfficesWorkspaceDeskPreview.gd` (`extends RefCounted`).
- Godot does not allow freeing `RefCounted` objects; calling `free()` produces:
  - `Can't free a RefCounted object.`
  - `Invalid call. Nonexistent function 'free (via call)' in base 'RefCounted (VrOfficesWorkspaceDeskPreview.gd)'.`
- When the cleanup call fails, the `DeskPreview` `Node3D` created for the ghost model is not queued for deletion and remains in the scene.

## Scope

- Rename the preview cleanup method from `free` to `dispose` (avoid engine name conflict / disallowed call).
- Update the placement controller to call `dispose` when ending placement.
- Add a VR Offices regression test that:
  - starts desk placement via `WorkspaceOverlay` signal
  - asserts `DeskPreview` exists
  - places the desk (LMB) and asserts `DeskPreview` disappears after placement ends

## Acceptance

- Placing a standing desk in a newly created workspace produces no Godot errors.
- After placement ends, the `VrOffices` root has no child node named `DeskPreview`.
- The new regression test fails before the fix and passes after.

## Files

- Modify:
  - `vr_offices/core/workspaces/VrOfficesWorkspaceDeskPreview.gd`
  - `vr_offices/core/workspaces/VrOfficesWorkspaceDeskPlacementController.gd`
- Add:
  - `tests/projects/vr_offices/test_vr_offices_workspace_desk_preview_cleanup.gd`
- Modify:
  - `docs/plan/v49-index.md`

## Steps (塔山开发循环)

1) **Red:** add `tests/projects/vr_offices/test_vr_offices_workspace_desk_preview_cleanup.gd` asserting the preview node is removed after placement ends.
2) **Verify Red:** run the test (expect FAIL because `DeskPreview` is still present).
   - Linux Godot:
     - `export GODOT_LINUX_EXE=/home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64`
     - `export HOME=/tmp/oa-home XDG_DATA_HOME=/tmp/oa-xdg-data XDG_CONFIG_HOME=/tmp/oa-xdg-config && mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"`
     - `timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_workspace_desk_preview_cleanup.gd`
3) **Green:** rename the cleanup method to `dispose` and update callers.
4) **Verify Green:** run the test again (expect PASS), then run the full suite:
   - `scripts/run_godot_tests.sh --suite vr_offices`
5) **Refactor:** keep naming consistent (preview lifecycle methods) without changing behavior beyond cleanup.

