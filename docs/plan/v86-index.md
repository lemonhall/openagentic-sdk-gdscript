# v86 index

Goal: remove overlap/confusion when entering NPC skills from dialogue by ensuring dialogue shell closes when skills overlay opens.

## Artifacts

- PRD: `docs/prd/2026-02-06-vr-offices-skills-overlay-zorder-and-shell-overlap.md`
- Plan: `docs/plan/v86-vr-offices-skills-overlay-zorder-and-shell-overlap.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Reproduce overlap via failing test | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_hides_dialogue_shell.gd` | done |
| M2 | Hide shell on skills open | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd` | done |
| M3 | Regressions remain stable | `scripts/run_godot_tests.sh --suite vr_offices` | done |

## Difference Review

- Changed: opening NPC skills from dialogue now closes/hides dialogue shell first.
- Kept: skills overlay opens with same NPC context; dialogue shell architecture remains unchanged.

## Evidence

- 2026-02-06:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_hides_dialogue_shell.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd` → PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` → PASS (online tests skipped unless `--oa-online-tests`)
