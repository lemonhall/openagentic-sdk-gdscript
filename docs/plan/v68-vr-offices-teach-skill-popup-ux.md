# v68 Plan — VR Offices: Teach-skill popup UX polish

## Goal

Fix the Teach-skill NPC picker UX issues:

1) Preview does not show the live office world.
2) Preview model is framed larger (camera/FOV/bounds).
3) `<` / `>` switching uses a small tween transition.

## PRD Trace

- `docs/prd/2026-02-05-vr-offices-teach-skill-popup-ux.md`
  - REQ-001 isolated preview viewport
  - REQ-002 better framing
  - REQ-003 tween switch

## Scope

- Update the popup scene nodes and script only.
- Add a minimal automated regression assertion for viewport isolation.

## Non-Goals

- No new effects, SFX, speech bubbles.

## Acceptance (hard DoD)

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_teach_skill_to_npc.gd` passes (and asserts preview viewport isolation).
- `scripts/run_godot_tests.sh --suite vr_offices` passes.

Anti-cheat clause:
- The isolation requirement must be checked via an explicit test assertion (`own_world_3d`), not by manual observation.

## Files

- Modify:
  - `vr_offices/ui/VendingMachineOverlay.tscn`
  - `vr_offices/ui/VrOfficesTeachSkillPopup.gd`
  - `tests/projects/vr_offices/test_vending_machine_overlay_teach_skill_to_npc.gd`

## Steps (塔山开发循环)

1) TDD Red: add failing assertion for `TeachPreviewViewport.own_world_3d`.
2) TDD Green: set `own_world_3d` and ensure preview is isolated.
3) Refactor/Polish (still green): adjust camera framing and add tween for switching.
4) Verify: run `vr_offices` suite and record evidence in `docs/plan/v68-index.md`.

