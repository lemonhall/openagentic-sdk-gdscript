# v14 Plan — VR Offices Desk Double-Click Opens Desks Tab

## Goal

Prevent regressions where adding a new tab (e.g., **Media**) changes tab indices and makes desk double-click open the overlay on the wrong tab.

## PRD Trace

- BUGFIX: Desk double-click opens settings overlay on the wrong tab after inserting Media tab.

## Scope

**In scope**
- Fix `IrcOverlay.open_for_desk()` to select the **Desks** tab reliably.
- Add a regression test for tab selection behavior.

**Out of scope**
- Changing desk selection/focus behavior inside the Desks tab.
- Reworking tab UI layout or renaming tabs.

## Acceptance

- Given an instantiated `IrcOverlay`, when `open_for_desk("any")` is called:
  - The `TabContainer` current tab is the child Control named `Desks`.
- The test must fail if `open_for_desk()` uses a hardcoded tab index that no longer points to `Desks`.

## Files

- Modify:
  - `vr_offices/ui/IrcOverlay.gd`
- Add:
  - `tests/projects/vr_offices/test_vr_offices_irc_overlay_open_for_desk_selects_desks_tab.gd`

## Steps (Red → Green → Refactor)

1) **TDD Red — write failing test**
   - Add the new test file asserting `open_for_desk()` selects the tab named `Desks`.
   - Verify it fails on current behavior:
     - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_irc_overlay_open_for_desk_selects_desks_tab.gd`

2) **TDD Green — implement minimal fix**
   - Update `open_for_desk()` to select the `Desks` tab by name (search children by `Control.name`), then set `tabs.current_tab` accordingly.
   - Re-run the test to green.

3) **Refactor (still green)**
   - If needed, extract a small helper (e.g., `_select_tab_by_name("Desks")`) and use it only where required.

## Risks

- The overlay may be used without the expected TabContainer structure; mitigate by falling back safely (no crash) if the tab isn’t found.

