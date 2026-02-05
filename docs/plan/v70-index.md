# v70 index

Goal: fix teach popup preview freezing after switching NPCs with `<` / `>` by keeping the preview viewport in `UPDATE_ALWAYS` while visible.

## Artifacts

- PRD: `docs/prd/2026-02-05-vr-offices-teach-popup-switch-keeps-animating.md`
- Plan: `docs/plan/v70-vr-offices-teach-popup-switch-keeps-animating.md`

## Evidence

- 2026-02-05
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_teach_popup_switch_keeps_animating.gd` PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` PASS

