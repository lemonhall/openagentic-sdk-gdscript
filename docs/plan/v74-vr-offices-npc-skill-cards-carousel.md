# v74 VR Offices: NPC skill cards carousel — layout polish

## Goal

In NPC personal skill management overlay, render skills as a card carousel (thumbnail surface + description text) instead of a vertical list. Navigation uses `<` / `>` buttons and keyboard left/right, with a short animated transition.

## Scope

- Replace skill list UI with a single card view + nav controls.
- Keep uninstall on the selected card.
- Keep thumbnail reuse from shared skill library (`thumbnail.png`).

## Acceptance (DoD)

1) NPC skills overlay shows one skill at a time as a “card”:
   - thumbnail as the card surface (top)
   - name + description below
2) Navigation:
   - `<` / `>` buttons switch cards
   - `Left/Right` (or `A/D`) switches cards
   - switching uses a short animation (fade/tilt/scale)
3) Thumbnail loading:
   - if `user://openagentic/saves/<save_id>/shared/skill_library/<skill_name>/thumbnail.png` exists, it is displayed on the card
4) Tests:
   - `scripts/run_godot_tests.sh --suite vr_offices` is green

## Files

Modify:

- `vr_offices/ui/VrOfficesNpcSkillsOverlay.tscn`
- `vr_offices/ui/VrOfficesNpcSkillsOverlay.gd`
- `tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd`

## Verify

- `scripts/run_godot_tests.sh --suite vr_offices`
