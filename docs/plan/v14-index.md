# v14 Index — VR Offices Desk Double-Click Opens Desks Tab

## Vision (v14)

Double-clicking a desk should open the “Settings” overlay focused on the **Desks** tab (not whichever tab index happens to be `2` after adding/removing tabs).

## Milestones (facts panel)

1. **Plan:** write an executable v14 plan with a regression test. (done)
2. **Test (RED):** add a failing test proving `open_for_desk()` selects the Desks tab. (done)
3. **Fix (GREEN):** make `open_for_desk()` select the **Desks** tab by name, not hardcoded index. (done)
4. **Verify:** run targeted headless tests. (done)

## Plans (v14)

- `docs/plan/v14-vr-offices-desk-doubleclick-opens-desks-tab.md`

## Definition of Done (DoD)

- `vr_offices/ui/SettingsOverlay.gd` does **not** hardcode tab indices for desk-focused open.
- Calling `open_for_desk(<desk_id>)` results in the TabContainer showing the **Desks** tab, even if tab ordering changes (e.g., Media tab inserted).
- Regression test added that fails on the old behavior and passes after the fix.

## Verification

- Run the new regression test:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_irc_overlay_open_for_desk_selects_desks_tab.gd`
- Run the existing settings overlay tab presence test (sanity):
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_settings_overlay_has_media_tab.gd`

## Evidence

- Tests:
  - `tests/projects/vr_offices/test_vr_offices_irc_overlay_open_for_desk_selects_desks_tab.gd`
