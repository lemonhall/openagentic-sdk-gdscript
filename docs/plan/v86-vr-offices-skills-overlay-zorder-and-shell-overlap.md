# v86 — VR Offices: fix dialogue shell / skills overlay overlap

## Goal

Implement `docs/prd/2026-02-06-vr-offices-skills-overlay-zorder-and-shell-overlap.md` by closing dialogue shell when opening NPC skills overlay.

## PRD Trace

- REQ-001 → Task 1 + Task 2
- REQ-002 → Task 2
- REQ-003 → Task 3

## Scope

### In scope

- Add failing test for overlap behavior.
- Close dialogue shell in `_on_dialogue_skills_pressed(...)` before opening skills overlay.
- Verify targeted + suite regressions.

### Out of scope

- Multi-step navigation/back behavior after closing skills.

## Acceptance

1) `test_vr_offices_skills_overlay_hides_dialogue_shell.gd` passes.
2) Existing NPC skills/dialogue shell tests stay green.
3) `--suite vr_offices` stays green.

## Files

Modify:

- `vr_offices/VrOffices.gd`

Add:

- `tests/projects/vr_offices/test_vr_offices_skills_overlay_hides_dialogue_shell.gd`

## Tashan Development Loop (v86)

### Task 1 — RED: reproduce overlay overlap

1) Add failing test: `tests/projects/vr_offices/test_vr_offices_skills_overlay_hides_dialogue_shell.gd`
2) Verify RED:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_hides_dialogue_shell.gd
```

Expected red: dialogue shell remains visible while skills overlay opens.

### Task 2 — GREEN: hide dialogue shell on skills open

- Update `VrOffices._on_dialogue_skills_pressed(...)` to close/hide `manager_dialogue_overlay` before opening `npc_skills_overlay`.

### Task 3 — Regression verification

Run:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_hides_dialogue_shell.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd
scripts/run_godot_tests.sh --suite vr_offices
```

## Evidence

- 2026-02-06 RED:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_hides_dialogue_shell.gd` → FAIL (`Expected dialogue shell hidden when skills overlay opens`)

- 2026-02-06 GREEN:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_skills_overlay_hides_dialogue_shell.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_dialogue_shell_layout.gd` → PASS
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd` → PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` → PASS (online tests skipped unless `--oa-online-tests`)
