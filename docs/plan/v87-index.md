# v87 index

Goal: after users close NPC skills, return them to the previous dialogue shell context.

## Artifacts

- PRD: `docs/prd/2026-02-06-vr-offices-skills-overlay-close-restores-dialogue-shell.md`
- Plan: `docs/plan/v87-vr-offices-skills-overlay-close-restores-dialogue-shell.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Reproduce missing return flow with failing test | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_close_restores_dialogue_shell.gd` | done |
| M2 | Restore dialogue shell + target identity on skills close | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_close_restores_dialogue_shell.gd` | done |
| M3 | Validate no regressions in skills/dialogue/smoke | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd` | done |

## Difference Review

- Changed: closing NPC skills (when entered from dialogue) restores the previous conversation shell.
- Kept: opening skills still hides dialogue shell to avoid overlap.
- Kept: existing skills and dialogue shell behavior for core flows.

## Evidence

- 2026-02-06:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_close_restores_dialogue_shell.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_hides_dialogue_shell.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd` → PASS
