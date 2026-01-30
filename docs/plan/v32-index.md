<!--
  v32 — VR Offices: IRC auto-connect without Enabled
-->

# v32 — IRC Auto-Connect (Remove Enabled) + Desk Ready Fix

## Vision (this version)

- IRC settings have no redundant `Enabled` switch — saving a host/port is enough.
- On game start (save load), desks automatically connect/reconnect without extra clicks.
- Desk indicators turn green when the desk channel is actually joined (ready), even when the server sends `JOIN :#channel`.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Remove `Enabled` from UX/config | Settings tab no longer has Enabled; config is “configured” when host is set | `tests/projects/vr_offices/test_vr_offices_irc_overlay_autosave.gd` + `tests/projects/vr_offices/test_vr_offices_irc_settings_persistence.gd` | todo |
| M2 | Desk ready detection | Desk link marks `ready=true` when JOIN channel appears in `trailing` | `tests/projects/vr_offices/test_vr_offices_desk_irc_link_smoke.gd` | todo |

## Plan Index

- `docs/plan/v32-irc-auto-connect-and-desk-ready.md`

