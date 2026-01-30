<!--
  v28 — VR Offices: Desk IRC status indicator
-->

# v28 — Desk IRC Status Indicator

## Vision (this version)

Each desk shows a small “plumbob-style” indicator above it that reflects IRC link health:

- Gray: IRC disabled / no link
- Yellow: connecting / registered but not ready
- Green: ready (joined and usable)
- Red: recent error / disconnected

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Indicator node exists | StandingDesk has `IrcIndicator` nodes | `tests/projects/vr_offices/test_vr_offices_desk_irc_indicator_smoke.gd` | todo |
| M2 | Indicator reacts to link signals | Status/ready/error update indicator colors | `tests/projects/vr_offices/test_vr_offices_desk_irc_indicator_smoke.gd` | todo |

## Plan Index

- `docs/plan/v28-desk-irc-indicator.md`

