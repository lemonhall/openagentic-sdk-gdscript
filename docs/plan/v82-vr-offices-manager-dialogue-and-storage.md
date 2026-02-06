# v82 — VR Offices: manager dialogue from manager desk + workspace-manager storage root

## Goal

Implement `docs/prd/2026-02-06-vr-offices-manager-dialogue-and-storage.md` so manager desk interaction opens a manager-specific dialogue UI and manager session/workspace data persists in a fixed workspace-specific manager path (not `npcs/npc_XX`).

## PRD Trace

- REQ-001 → Task 1 + Task 2
- REQ-002 → Task 3
- REQ-003 → Task 4
- REQ-004 → Task 1/3/4 tests

## Scope

### In scope

- Manager desk pick collider + input routing to manager dialogue.
- New manager dialogue overlay scene (left chat compatible with `DialogueOverlay`, right manager preview).
- OA path helpers for workspace manager fixed root.
- Manager turn hook context for active NPC roster in the same workspace.

### Out of scope

- Full manager automation policy.
- Replacing standard NPC dialogue path.

## Acceptance

1) Double-click manager desk opens manager dialogue overlay.
2) Manager dialogue uses deterministic manager identity per workspace.
3) Manager events/workspace path resolves under:
   - `user://openagentic/saves/<save_id>/workspaces/<workspace_id>/manager/...`
4) Manager before-turn hook injects manager role context with active workspace NPC list.
5) Existing NPC dialogue flow remains unaffected.

## Files

Modify (expected):

- `vr_offices/core/workspaces/VrOfficesWorkspaceManagerDeskDefaults.gd`
- `vr_offices/core/input/VrOfficesClickPicker.gd`
- `vr_offices/core/input/VrOfficesInputController.gd`
- `vr_offices/VrOffices.gd`
- `addons/openagentic/core/OAPaths.gd`
- `vr_offices/core/agent/VrOfficesAgentBridge.gd`

Add (expected):

- `vr_offices/ui/VrOfficesManagerDialogueOverlay.tscn`
- `vr_offices/ui/VrOfficesManagerDialogueOverlay.gd`
- `tests/addons/openagentic/test_oa_paths_workspace_manager.gd`
- `tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd`
- `tests/projects/vr_offices/test_vr_offices_manager_role_context_hook.gd`

## Tashan Development Loop (v82)

### Task 1 — RED: manager desk click opens manager dialogue

1) Add failing test: `test_vr_offices_manager_desk_dialogue_and_storage.gd`
2) Verify red:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd
```

Expected RED: manager desk not pickable / no manager dialogue overlay visible.

### Task 2 — GREEN: manager desk picking + manager dialogue overlay

- Add manager desk pick collider + group.
- Add manager dialogue overlay and wire open/close.
- Route manager desk double-click to manager dialogue entry.

### Task 3 — RED→GREEN: manager fixed storage root path

1) Add failing test: `test_oa_paths_workspace_manager.gd`
2) Verify red.
3) Implement OAPaths helpers for workspace manager root/session/events/workspace/skills.
4) Wire manager dialogue to use manager-special `npc_id` and workspace manager paths.

### Task 4 — RED→GREEN: manager role context hook

1) Add failing test: `test_vr_offices_manager_role_context_hook.gd`
2) Verify red.
3) Inject manager role prefix + active workspace NPC roster in before-turn hook path.

### Task 5 — Refactor + verification

- Keep flow minimal and avoid changing generic NPC behavior.
- Run targeted tests:

```bash
scripts/run_godot_tests.sh --one tests/addons/openagentic/test_oa_paths_workspace_manager.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_role_context_hook.gd
```

## Evidence

- 2026-02-06 RED:
  - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_oa_paths_workspace_manager.gd` → FAIL (missing OAPaths manager functions)
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd` → FAIL (missing manager path helpers / overlay route)
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_role_context_hook.gd` → FAIL (no manager context override)
- 2026-02-06 GREEN:
  - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_oa_paths_workspace_manager.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_role_context_hook.gd` → PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` → PASS (online tests skipped unless `--oa-online-tests`)
