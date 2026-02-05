# v67 Plan — VR Offices: Teach shared skill to active NPC

## Goal

From `VendingMachineOverlay` Library tab, select an installed shared skill and teach it to an active NPC by copying the skill directory into the NPC private workspace.

## PRD Trace

- `docs/prd/2026-02-05-vr-offices-teach-skill-to-npc.md`
  - REQ-001 Teach button in Library tab
  - REQ-002 Arrow-based NPC picker
  - REQ-003 Best-effort preview (headless-safe)
  - REQ-004 Copy into NPC workspace (overwrite)
  - REQ-005 Automated test

## Scope

- Add teach popup UI and wiring in `VendingMachineOverlay`.
- Add a small core helper to copy a shared skill to an NPC workspace safely.
- Add an offline automated test.

## Non-Goals

- Animations/SFX/speech bubbles.
- Bulk teaching / skill versioning UI.

## Acceptance (hard DoD)

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_teach_skill_to_npc.gd` passes.
- `scripts/run_godot_tests.sh --suite vr_offices` passes.

Anti-cheat clause:
- The test must assert the `user://.../npcs/<npc_id>/workspace/skills/<skill>/SKILL.md` file exists after teaching (filesystem evidence), not just a status label.

## Files

- Add:
  - `vr_offices/core/skill_library/VrOfficesTeachSkillToNpc.gd`
  - `vr_offices/ui/VrOfficesTeachSkillPopup.gd`
  - `tests/projects/vr_offices/test_vending_machine_overlay_teach_skill_to_npc.gd`
- Modify:
  - `vr_offices/ui/VendingMachineOverlay.tscn`
  - `vr_offices/ui/VendingMachineOverlay.gd`

## Steps (塔山开发循环)

1) TDD Red: add failing teach test (missing teach UI / copy helper).
2) TDD Green: implement copy helper + wire UI popup picker and confirm action.
3) Refactor: keep UI logic small by delegating to popup script / helper.
4) Verify: run `vr_offices` suite and record evidence in `docs/plan/v67-index.md`.

