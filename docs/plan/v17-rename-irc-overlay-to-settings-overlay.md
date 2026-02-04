# v17 Plan — Rename IrcOverlay to SettingsOverlay

## Goal

Rename the settings overlay scene/script so future contributors can find it quickly (search for “settings”), without changing behavior.

## PRD Trace

- DevEx refactor: naming clarity and discoverability.

## Scope

**In scope**
- Rename files:
  - `vr_offices/ui/IrcOverlay.tscn` → `vr_offices/ui/SettingsOverlay.tscn`
  - `vr_offices/ui/IrcOverlay.gd` → `vr_offices/ui/SettingsOverlay.gd`
  - Update any `.uid` file accordingly
- Update references in:
  - `vr_offices/VrOffices.tscn`, `vr_offices/VrOffices.gd`
  - Input controller hook for desk double-click
  - Tests that load/locate the overlay
  - Documentation and plan docs that mention the old name/path

**Out of scope**
- Changing UI content, tabs, or behavior.

## Acceptance

- Overlay can still be opened from the world scene.
- Desk double-click still opens the overlay focused on the Desks tab.
- Tests that mention the overlay are updated and pass.

## Steps (Red → Green → Refactor)

1) **Red**: update tests to load `SettingsOverlay.tscn` (should fail before rename).
2) **Green**: rename scene/script and update all references.
3) **Refactor**: keep compatibility helpers if needed (optional aliases), but prefer the new names.
4) **Verify**: run `scripts/run_godot_tests.sh --suite vr_offices`.

## Risks

- Missing one reference breaks scene instantiation; mitigate by `rg "IrcOverlay"` to zero and running tests.
