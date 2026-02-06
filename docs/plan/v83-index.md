# v83 index

Goal: unify all NPC dialogue entry to manager-style shell (left chat + right model), and enable manager preview idle autoplay while keeping manager-special storage/context behavior stable.

## Artifacts

- PRD: `docs/prd/2026-02-06-vr-offices-unified-dialogue-shell-and-manager-idle.md`
- Plan: `docs/plan/v83-vr-offices-unified-dialogue-shell-and-manager-idle.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Manager preview idle autoplay | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_dialogue_preview_idle.gd` | done |
| M2 | NPC talk unified to manager-style shell | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd` | done |
| M3 | No regression in manager storage/context + NPC dialogue flows | Targeted regression commands in v83 plan | done |

## Difference Review

- Changed: standard NPC talk now opens the same shell style as manager (left chat, right model preview).
- Changed: manager preview now proactively autoplays a looping idle-like animation.
- Kept: manager fixed storage root and manager context hook behavior.

## Evidence

- 2026-02-06:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_dialogue_preview_idle.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd` → PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` → PASS (online tests skipped unless `--oa-online-tests`)
  - Targeted regression commands (smoke/history/double-click/focus/manager path/context) → PASS
