# v87 — VR Offices: restore dialogue after closing NPC skills

## Goal

Implement `docs/prd/2026-02-06-vr-offices-skills-overlay-close-restores-dialogue-shell.md` so users return to the previous dialogue shell after exiting skills.

## PRD Trace

- REQ-001 → Task 1 + Task 2
- REQ-002 → Task 1 + Task 2
- REQ-003 → Task 3

## Scope

### In scope

- Add failing test for skills-close restore path.
- Emit close event from `VrOfficesNpcSkillsOverlay`.
- Restore dialogue context from `VrOffices` after skills close.
- Run targeted regressions.

### Out of scope

- Generic navigation history for all overlays.
- New UI components for back-stack breadcrumbs.

## Acceptance

1) `test_vr_offices_skills_overlay_close_restores_dialogue_shell.gd` passes.
2) `test_vr_offices_skills_overlay_hides_dialogue_shell.gd` remains green.
3) Existing skills/dialogue/smoke regressions remain green.

## Files

Modify:

- `vr_offices/VrOffices.gd`
- `vr_offices/ui/VrOfficesNpcSkillsOverlay.gd`

Add:

- `tests/projects/vr_offices/test_vr_offices_skills_overlay_close_restores_dialogue_shell.gd`

## Tashan Development Loop (v87)

### Task 1 — RED: reproduce missing return flow

1) Add failing test:
   - `tests/projects/vr_offices/test_vr_offices_skills_overlay_close_restores_dialogue_shell.gd`
2) Verify RED:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_close_restores_dialogue_shell.gd
```

Expected red: `Expected dialogue shell to restore after closing skills`.

### Task 2 — GREEN: restore previous dialogue on skills close

- Add `closed` signal to `VrOfficesNpcSkillsOverlay` and emit it in `close()`.
- In `VrOffices`, cache dialogue identity context on `_on_dialogue_skills_pressed(...)`.
- On overlay `closed`, reopen manager dialogue shell and call `enter_talk_by_id(...)` for cached target.

### Task 3 — Regression verification

Run:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_close_restores_dialogue_shell.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_hides_dialogue_shell.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd
```

## Evidence

- 2026-02-06 RED:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_close_restores_dialogue_shell.gd` → FAIL (`Expected dialogue shell to restore after closing skills`)

- 2026-02-06 GREEN:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_close_restores_dialogue_shell.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_hides_dialogue_shell.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd` → PASS
