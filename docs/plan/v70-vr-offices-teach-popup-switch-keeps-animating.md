# v70 Plan — VR Offices: Teach popup switching keeps preview animating

## Goal

Ensure the Teach-skill NPC picker keeps rendering animations after switching NPC selection.

## PRD Trace

- `docs/prd/2026-02-05-vr-offices-teach-popup-switch-keeps-animating.md`
  - REQ-001 switching does not stop updates
  - REQ-002 regression test

## Scope

- Add a headless-test hook to force “non-headless” behavior for the popup script.
- Fix `_shift()` so it never leaves the preview viewport in `UPDATE_ONCE` while visible.
- Add an automated regression test.

## Acceptance (hard DoD)

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_teach_popup_switch_keeps_animating.gd` passes.
- `scripts/run_godot_tests.sh --suite vr_offices` passes.

## Files

- Add:
  - `tests/projects/vr_offices/test_teach_popup_switch_keeps_animating.gd`
- Modify:
  - `vr_offices/ui/VrOfficesTeachSkillPopup.gd`

## Steps (塔山开发循环)

1) TDD Red: add test that fails because viewport ends in `UPDATE_ONCE`.
2) TDD Green: keep `UPDATE_ALWAYS` while popup visible.
3) Verify: run `vr_offices` suite and record evidence in `docs/plan/v70-index.md`.

