<!--
  v31 — VR Offices: Desk IRC reconnect UX
-->

# v31 — Desk IRC Reconnect UX

## Vision (this version)

- It’s obvious why desk indicators might stay gray (IRC is opt-in via `Enabled`).
- The IRC overlay “Desks” tab provides a manual action to reconnect desks when needed.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Desks reconnect button | Desks tab has a “Reconnect all” action wired to the desk manager | `tests/test_vr_offices_irc_overlay_desks_reconnect.gd` | todo |
| M2 | Safe reconnect hook | Desk IRC link supports a manual reconnect without relying on config re-apply side effects | `tests/test_vr_offices_desk_irc_link_smoke.gd` | todo |

## Plan Index

- `docs/plan/v31-irc-desks-reconnect.md`

