<!--
  v27 — VR Offices: IRC settings persistence + desk double-click fix
-->

# v27 — Fix IRC Settings + Desk Double-Click

## Goals

- IRC settings entered in the in-game overlay persist reliably across save/load.
- Double-clicking a desk reliably opens the IRC overlay focused on that desk.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Persist-on-test + explicit save/load | Connecting/joining from Test implicitly saves config; Settings has Save + Reload | `tests/test_vr_offices_irc_overlay_smoke.gd` + manual | todo |
| M2 | Desk click not eaten by workspace selection | Workspace selection does not consume clicks on desk pick layer | `tests/test_vr_offices_desk_pick_collider.gd` + manual | todo |

## Plan Index

- `docs/plan/v27-fix-irc-ui-and-desk-click.md`

