# v83 — VR Offices: unified NPC dialogue shell + manager preview idle autoplay

## Goal

Implement `docs/prd/2026-02-06-vr-offices-unified-dialogue-shell-and-manager-idle.md` by:

- enabling manager preview idle autoplay, and
- routing normal NPC dialogue to the same shell style as manager dialogue (left chat + right model).

## PRD Trace

- REQ-001 → Task 1
- REQ-002 → Task 2
- REQ-003 → Task 3
- REQ-004 → Task 3

## Scope

### In scope

- Manager preview idle autoplay + loop enforcement for preview models.
- NPC talk entry path unification to `VrOfficesManagerDialogueOverlay` shell.
- Input routing updates so click/key talk entry uses owner talk method consistently.
- Regression tests for smoke/history/double-click/focus + manager path/context.

### Out of scope

- Rebuilding `DialogueOverlay.tscn` internals.
- Manager orchestration policy changes.

## Acceptance

1) `test_vr_offices_manager_dialogue_preview_idle.gd` passes.
2) `test_vr_offices_npc_dialogue_shell_layout.gd` passes.
3) Existing manager storage/context tests pass.
4) Existing dialogue smoke/history/focus/double-click tests pass.

## Files

Modify:

- `vr_offices/ui/VrOfficesManagerDialogueOverlay.gd`
- `vr_offices/VrOffices.gd`
- `vr_offices/core/input/VrOfficesInputController.gd`
- `tests/projects/vr_offices/test_vr_offices_smoke.gd`
- `tests/projects/vr_offices/test_vr_offices_per_npc_history.gd`
- `tests/projects/vr_offices/test_vr_offices_double_click_talk.gd`

Add:

- `tests/projects/vr_offices/test_vr_offices_manager_dialogue_preview_idle.gd`
- `tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd`

## Tashan Development Loop (v83)

### Task 1 — RED→GREEN: manager preview idle autoplay

1) RED test added: `test_vr_offices_manager_dialogue_preview_idle.gd`
2) RED command:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_dialogue_preview_idle.gd
```

Expected red: missing helper / no idle autoplay verification.

3) GREEN implementation:

- `VrOfficesManagerDialogueOverlay` now freezes preview gameplay scripts while keeping `AnimationPlayer` active.
- Reuses `VrOfficesTeachSkillPopup.autoplay_idle_animation_for_preview(...)` to autoplay and loop animation.

### Task 2 — RED→GREEN: all NPC talk opens manager-style shell

1) RED test added: `test_vr_offices_npc_dialogue_shell_layout.gd`
2) RED command:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd
```

Expected red: NPC talk not opening manager shell.

3) GREEN implementation:

- `VrOffices.gd` uses embedded dialogue from `VrOfficesManagerDialogueOverlay` as the active runtime dialogue surface.
- `_enter_talk(npc)` now opens shell via `open_for_npc(...)` with NPC name/model.
- Manager desk path reuses same dialogue controller via `enter_talk_by_id(...)`.
- `VrOfficesInputController` routes click/key talk entry through owner `_enter_talk`, preserving shell behavior.

### Task 3 — Refactor + regression verification

Run:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_per_npc_history.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_double_click_talk.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_focus.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_desk_dialogue_and_storage.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_dialogue_preview_camera.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd
scripts/run_godot_tests.sh --one tests/addons/openagentic/test_oa_paths_workspace_manager.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_role_context_hook.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_dialogue_preview_idle.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd
```

## Evidence

- 2026-02-06 RED:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_dialogue_preview_idle.gd` → FAIL (`Expected manager overlay idle autoplay test helper`)
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd` → FAIL (`Expected NPC dialogue to open manager-style shell`)

- 2026-02-06 GREEN:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_manager_dialogue_preview_idle.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_core_layout_guard.gd` → PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` → PASS (online tests skipped unless `--oa-online-tests`)
  - All listed Task 3 regression commands above → PASS
