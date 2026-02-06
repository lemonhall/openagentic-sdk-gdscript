# v85 index

Goal: ensure manager avatar remains unique by excluding manager model from `add_npc` profile allocation.

## Artifacts

- PRD: `docs/prd/2026-02-06-vr-offices-exclude-manager-model-from-add-npc.md`
- Plan: `docs/plan/v85-vr-offices-exclude-manager-model-from-add-npc.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Add failing/green exclusion test | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_add_npc_excludes_manager_model.gd` | done |
| M2 | Profile pool exclusion + world wiring | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd` | done |
| M3 | Full VR Offices regression confidence | `scripts/run_godot_tests.sh --suite vr_offices` | done |

## Difference Review

- New: manager model is now permanently excluded from runtime `add_npc` allocation pool.
- Updated: max addable NPC capacity equals non-manager model count.
- Kept: manager desk/dialogue/storage behaviors unchanged.

## Evidence

- 2026-02-06:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_add_npc_excludes_manager_model.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd` → PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` → PASS (online tests skipped unless `--oa-online-tests`)
