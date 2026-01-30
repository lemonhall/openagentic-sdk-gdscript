<!--
  v25 — VR Offices: In-game IRC settings + desk status UI
-->

# v25 — VR Offices IRC Settings UI

## Vision (this version)

VR Offices has an in-game UI that:

- Configures IRC connection info (host/port/tls/password, etc.).
- Persists that config via the existing save/load system (`user://openagentic/saves/<save_id>/vr_offices/state.json`).
- Provides a “Test” area to connect + join a channel (demo_irc-level verification, but with VR Offices UI style).
- Provides a “Desks” view to verify each desk’s IRC link status (connected/registered/joined/ready + basic logs).

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Persist IRC config in save state | Save/load roundtrip keeps `state.irc` | `tests/test_vr_offices_irc_settings_persistence.gd` | todo |
| M2 | In-game IRC overlay UI | Button + hotkey open overlay; edit/save config; test connect/join UI exists | `tests/test_vr_offices_irc_overlay_smoke.gd` | todo |
| M3 | Desk status verification UI | Overlay lists desks and shows per-desk `DeskIrcLink` status/channel/logs | `tests/test_vr_offices_desk_irc_link_smoke.gd` + manual in-game check | todo |

## Plan Index

- `docs/plan/v25-vr-offices-irc-ui.md`

## Known Gaps (end-of-version checklist)

- [ ] Decide whether desk IRC logs should be persisted (currently in-memory only).
- [ ] Stronger “ready” definition (wait for 366 end-of-NAMES, etc.).
- [ ] Multi-desk connection pooling (if needed for scale).

