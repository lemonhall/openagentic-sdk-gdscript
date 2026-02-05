# v66 Plan — VR Offices: Skill Library uninstall/reinstall + open folder

## Goal

- Fix the Library uninstall → reinstall regression (uninstall must remove the root skill directory).
- Add an `Open Folder` button to the Library tab to reveal the shared skill library directory in the OS file manager.

## PRD Trace

- `docs/prd/2026-02-05-vr-offices-shared-skill-library.md`
  - REQ-010 Uninstall truly removes the skill directory (reinstall works)
  - REQ-011 Open the shared library folder in OS file manager

## Scope

- `VendingMachineOverlay` Library tab UX only (no new installer sources).
- Add automated regression tests.

## Non-Goals

- No “teach NPC” implementation.
- No “update” flow for already-installed skills beyond making uninstall reliable.

## Acceptance (hard DoD)

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_uninstall_reinstall.gd` passes.
- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_library_tab_manage_and_filter.gd` passes.
- `scripts/run_godot_tests.sh --suite vr_offices` passes.

Anti-cheat clause:
- The uninstall→reinstall test must uninstall via the Library tab code path and then re-install without resetting the filesystem between steps.

## Files

- Modify:
  - `vr_offices/ui/VendingMachineOverlay.tscn`
  - `vr_offices/ui/VendingMachineOverlay.gd`
  - `tests/projects/vr_offices/test_vending_machine_overlay_library_tab_manage_and_filter.gd`
- Add:
  - `tests/projects/vr_offices/test_vending_machine_overlay_uninstall_reinstall.gd`

## Steps (塔山开发循环)

1) TDD Red: add uninstall→reinstall regression test (fails on leftover dir bug).
2) TDD Green: ensure uninstall removes the root directory and refreshes manifest/list.
3) TDD Red: add Library `Open Folder` button presence test (no crash when pressed in headless).
4) TDD Green: wire button and handler (headless-safe).
5) Verify: run `vr_offices` suite and record evidence in `docs/plan/v66-index.md`.
