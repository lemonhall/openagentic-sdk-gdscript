# v66 index

Goal: fix Library uninstall → reinstall bug; add an “Open Folder” button to reveal the shared skill library directory in the OS file manager.

## Artifacts

- PRD: `docs/prd/2026-02-05-vr-offices-shared-skill-library.md` (REQ-010, REQ-011)
- Plan: `docs/plan/v66-vr-offices-skill-library-uninstall-reinstall-open-folder.md`

## Evidence

- 2026-02-05
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_uninstall_reinstall.gd` PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_library_tab_manage_and_filter.gd` PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` PASS
