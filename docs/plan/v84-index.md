# v84 index

Goal: add explicit target/workspace identity labels in the unified dialogue shell right panel, reducing context confusion during multi-NPC management.

## Artifacts

- PRD: `docs/prd/2026-02-06-vr-offices-dialogue-shell-identity-labels.md`
- Plan: `docs/plan/v84-vr-offices-dialogue-shell-identity-labels.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Add shell identity/workspace labels | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_shell_identity_labels.gd` | done |
| M2 | Wire manager/NPC label updates | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd` | done |
| M3 | Regression stability (manager path + smoke + layout guard) | Verify list in v84 plan | done |

## Difference Review

- New: shell right panel now displays current target label (`对象`) and workspace label (`工作区`).
- New: NPC dialogue entry passes workspace context into shell for accurate identity display.
- Kept: manager workspace-special storage behavior and existing shell interaction flow.

## Evidence

- 2026-02-06:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_shell_identity_labels.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_core_layout_guard.gd` → PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` → PASS (online tests skipped unless `--oa-online-tests`)
