# v77 VR Offices: NPC skills summary UX + folder button

## Goal

- Make the summary area in the NPC skills overlay look better (padding, ~2 lines).
- Expand summary length slightly so it’s not too terse.
- Keep summary consistent by triggering regeneration on open when cached state is missing/errored.
- Add a button to open the NPC skills folder in the OS file manager.
- Pull the 3D preview camera back a bit to avoid “too close”.

## Acceptance (DoD)

1) Summary UI:
   - Summary text has left/right padding.
   - Summary reserves space for about two lines (wrap enabled).
2) Summary generation:
   - Summary clamp limit increased (regression test updated).
   - On opening the overlay, if cached summary is missing or has `last_error`, queue a forced refresh.
3) Utility:
   - A button opens the NPC skills folder (uses `OS.shell_open(ProjectSettings.globalize_path(...))`).
4) Preview:
   - Camera framing feels less close-up (increase framing distance).
5) Verification:
   - `scripts/run_godot_tests.sh --suite vr_offices` is green.

## Files

Modify:

- `vr_offices/core/skills/VrOfficesNpcSkillsService.gd`
- `vr_offices/ui/VrOfficesNpcSkillsOverlay.tscn`
- `vr_offices/ui/VrOfficesNpcSkillsOverlay.gd`

Create/Modify tests:

- `tests/projects/vr_offices/test_npc_skills_summary_length.gd`

## Verify

- `scripts/run_godot_tests.sh --suite vr_offices`
