# v69 Plan — VR Offices: Teach popup preview idle animation

## Goal

Avoid T-pose in the Teach popup preview by auto-playing a looped idle (or fallback) animation when the preview model includes animations.

## PRD Trace

- `docs/prd/2026-02-05-vr-offices-teach-popup-preview-idle-animation.md`
  - REQ-001 autoplay idle
  - REQ-002 safe preview
  - REQ-003 automated test

## Scope

- Add a small helper in `VrOfficesTeachSkillPopup.gd` to pick+play a looped animation.
- Adjust preview “freeze” behavior to not stop AnimationPlayers.
- Add a headless-safe test for the helper.

## Acceptance (hard DoD)

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_teach_popup_preview_autoplays_idle_animation.gd` passes.
- `scripts/run_godot_tests.sh --suite vr_offices` passes.

Anti-cheat clause:
- The test must construct an `AnimationPlayer` + `Animation` in code and assert `is_playing()` after calling the helper.

## Files

- Add:
  - `tests/projects/vr_offices/test_teach_popup_preview_autoplays_idle_animation.gd`
- Modify:
  - `vr_offices/ui/VrOfficesTeachSkillPopup.gd`

## Steps (塔山开发循环)

1) TDD Red: add failing autoplay test (helper missing / not playing).
2) TDD Green: implement helper and wire preview path to use it.
3) Verify: run `vr_offices` suite and record evidence in `docs/plan/v69-index.md`.

