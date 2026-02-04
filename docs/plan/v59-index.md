# v59 index

Goal: double-click the workspace vending machine to open a dedicated overlay panel (tabbed UI with a single `Skills` tab for now), using the same visual style patterns as `SettingsOverlay`.

## Artifacts

- Plan: `docs/plan/v59-vr-offices-vending-machine-skills-overlay.md`

## Evidence (2026-02-04)

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_vending_machine_double_click_opens_overlay.gd` (PASS)
- `scripts/run_godot_tests.sh --suite vr_offices` (PASS)
