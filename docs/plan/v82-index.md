# v82 index

Goal: manager desk click opens a manager-specific dialogue (left chat + right model), with manager data isolated to a fixed workspace-manager storage root.

## Artifacts

- PRD: `docs/prd/2026-02-06-vr-offices-manager-dialogue-and-storage.md`
- Plan: `docs/plan/v82-vr-offices-manager-dialogue-and-storage.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Manager desk click route + manager dialogue overlay | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd` | done |
| M2 | Manager-special OAPaths root | `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_oa_paths_workspace_manager.gd` | done |
| M3 | Manager context injection for active workspace NPC roster | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_role_context_hook.gd` | done |

## Difference Review

- New: manager is now treated as workspace-level special identity rather than generic `npc_XX`.
- New: manager dialogue gets dedicated UI surface with model preview.
- New: manager turns include workspace manager responsibility context + active NPC list.

## Evidence

- 2026-02-06:
  - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_oa_paths_workspace_manager.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_role_context_hook.gd` → PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` → PASS (online tests skipped unless `--oa-online-tests`)
