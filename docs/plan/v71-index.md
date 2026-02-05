# v71 index

Goal: add NPC personal skill management UI (entry from Dialogue overlay), including learned-skill cards + uninstall, plus background LLM-generated capability summary cached per NPC.

## Artifacts

- PRD: `docs/prd/2026-02-05-vr-offices-npc-skill-management.md`
- Plan: `docs/plan/v71-vr-offices-npc-skill-management.md`

## Evidence

- 2026-02-05
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd` PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd` PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` PASS

