# v17 Index — Rename IrcOverlay to SettingsOverlay

## Vision (v17)

The in-game “settings” overlay is easy to find and reason about:

- The scene/script are named for what they are (`SettingsOverlay`), not a historical feature (`IrcOverlay`).
- References in code/tests/docs use the new name so searching for “settings overlay” works.

## Milestones (facts panel)

1. **Plan:** write an executable v17 plan. (done)
2. **Red:** update tests to reference the new SettingsOverlay path/name (fails until rename). (done)
3. **Green:** rename scene/script + update all code references. (done)
4. **Docs:** update repo docs/plans to the new name. (done)
5. **Verify:** run headless vr_offices tests. (done)

## Plans (v17)

- `docs/plan/v17-rename-irc-overlay-to-settings-overlay.md`

## Definition of Done (DoD)

- `res://vr_offices/ui/SettingsOverlay.tscn` and `res://vr_offices/ui/SettingsOverlay.gd` exist and are used by `VrOffices.tscn`.
- No remaining references to `IrcOverlay.tscn` or `IrcOverlay.gd` in code/tests/docs.
- Headless tests related to the overlay pass.

## Verification

- Targeted:
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_smoke.gd`
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_settings_overlay_has_media_tab.gd`
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_settings_overlay_has_tavily_tab.gd`
