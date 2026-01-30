<!--
  v29 — VR Offices: Fix desk centering + indicator visibility
-->

# v29 — Fix Desk Centering + Indicator Visibility

## Vision (this version)

- `StandingDesk` model, pick collider, and IRC indicator stay aligned (no mesh drifting away from the clickable desk).
- IRC indicator is readable at a glance even in the default/disabled (gray) state.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Desk centering ignores non-model meshes | `ensure_centered()` centers only the GLB model subtree | `tests/projects/vr_offices/test_vr_offices_standing_desk_centering.gd` | todo |
| M2 | Indicator default visibility | Gray/unknown indicator is not near-invisible | `tests/projects/vr_offices/test_vr_offices_desk_irc_indicator_smoke.gd` | todo |

## Plan Index

- `docs/plan/v29-standing-desk-centering-and-indicator-visibility.md`

