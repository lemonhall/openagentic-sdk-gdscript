# v85 — VR Offices: exclude manager model from `add_npc`

## Goal

Implement `docs/prd/2026-02-06-vr-offices-exclude-manager-model-from-add-npc.md` so manager model remains unique and cannot be picked by normal NPC spawning.

## PRD Trace

- REQ-001 → Task 1 + Task 2
- REQ-002 → Task 2
- REQ-003 → Task 3
- REQ-004 → Task 4

## Scope

### In scope

- Add deterministic regression test for manager-model exclusion.
- Add exclusion support in NPC profile pool.
- Mark manager model as excluded during world initialization.
- Update smoke capacity expectation to non-manager model count.

### Out of scope

- Save migration for old duplicates.

## Acceptance

1) `test_vr_offices_add_npc_excludes_manager_model.gd` passes.
2) `test_vr_offices_smoke.gd` passes with new capacity baseline.
3) `test_vr_offices_manager_desk_dialogue_and_storage.gd` remains green.
4) `--suite vr_offices` remains green.

## Files

Modify:

- `vr_offices/core/npcs/VrOfficesNpcProfiles.gd`
- `vr_offices/VrOffices.gd`
- `tests/projects/vr_offices/test_vr_offices_smoke.gd`

Add:

- `tests/projects/vr_offices/test_vr_offices_add_npc_excludes_manager_model.gd`

## Tashan Development Loop (v85)

### Task 1 — RED: manager model should be excluded from add_npc

1) Add failing test: `tests/projects/vr_offices/test_vr_offices_add_npc_excludes_manager_model.gd`
2) Verify RED:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_add_npc_excludes_manager_model.gd
```

Expected red: add_npc still reaches full 12 and includes manager model.

### Task 2 — GREEN: profile-pool level exclusion

- Add exclusion set to `VrOfficesNpcProfiles`.
- Add `exclude_model(model_path)` and exclusion re-apply in `reset()`.
- Ensure `release_model(...)` does not re-enable excluded model.

### Task 3 — GREEN: world wiring + smoke alignment

- Call `_profiles.exclude_model(_OAData.MANAGER_MODEL_PATH)` in `VrOffices._ready()`.
- Update smoke expected max to `_OAData.MODEL_PATHS.size() - 1`.

### Task 4 — Regression verification

Run:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_add_npc_excludes_manager_model.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_core_layout_guard.gd
scripts/run_godot_tests.sh --suite vr_offices
```

## Evidence

- 2026-02-06 RED:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_add_npc_excludes_manager_model.gd` → FAIL (`expected 11, got 12`)

- 2026-02-06 GREEN:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_add_npc_excludes_manager_model.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_core_layout_guard.gd` → PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` → PASS (online tests skipped unless `--oa-online-tests`)
