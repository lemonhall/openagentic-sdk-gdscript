# v84 — VR Offices: dialogue shell right-panel identity labels

## Goal

Implement `docs/prd/2026-02-06-vr-offices-dialogue-shell-identity-labels.md` so shell right panel clearly shows current target and workspace context.

## PRD Trace

- REQ-001 → Task 1 + Task 2
- REQ-002 → Task 1 + Task 2
- REQ-003 → Task 2
- REQ-004 → Task 3

## Scope

### In scope

- Add right-panel labels (`对象` + `工作区`) in `VrOfficesManagerDialogueOverlay`.
- Wire manager and NPC open paths to update those labels.
- Pass NPC workspace id from world entry point into shell open call.
- Add/execute regression tests.

### Out of scope

- Changes to session storage schema.
- New manager policy behavior.

## Acceptance

1) `test_vr_offices_dialogue_shell_identity_labels.gd` passes.
2) Existing shell behavior tests still pass.
3) Manager path and core layout guard remain green.

## Files

Modify:

- `vr_offices/ui/VrOfficesManagerDialogueOverlay.tscn`
- `vr_offices/ui/VrOfficesManagerDialogueOverlay.gd`
- `vr_offices/VrOffices.gd`

Add:

- `tests/projects/vr_offices/test_vr_offices_dialogue_shell_identity_labels.gd`

## Tashan Development Loop (v84)

### Task 1 — RED: identity/workspace labels in shell panel

1) Add failing test:

- `tests/projects/vr_offices/test_vr_offices_dialogue_shell_identity_labels.gd`

2) Verify RED:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_shell_identity_labels.gd
```

Expected red: missing identity/workspace label nodes.

### Task 2 — GREEN: add labels and wire manager/NPC context

- Add `IdentityPanel` with `IdentityNameLabel` and `IdentityWorkspaceLabel` under shell right panel.
- Add `_set_identity_labels(...)` and call it in `open_for_manager(...)` and `open_for_npc(...)`.
- Extend `open_for_npc(...)` to accept `workspace_id`.
- In `VrOffices._enter_talk(...)`, resolve NPC workspace from node ancestry and pass into shell open call.

### Task 3 — Regression verification

Run:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_shell_identity_labels.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_core_layout_guard.gd
scripts/run_godot_tests.sh --suite vr_offices
```

## Evidence

- 2026-02-06 RED:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_shell_identity_labels.gd` → FAIL (`Missing identity name label in shell preview panel`)

- 2026-02-06 GREEN:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_shell_identity_labels.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_core_layout_guard.gd` → PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` → PASS (online tests skipped unless `--oa-online-tests`)
