# v69 index

Goal: make Teach popup preview NPC play a looped idle animation (avoid T-pose) while keeping preview isolated and safe.

## Artifacts

- PRD: `docs/prd/2026-02-05-vr-offices-teach-popup-preview-idle-animation.md`
- Plan: `docs/plan/v69-vr-offices-teach-popup-preview-idle-animation.md`

## Evidence

- 2026-02-05
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_teach_popup_preview_autoplays_idle_animation.gd` PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` PASS

