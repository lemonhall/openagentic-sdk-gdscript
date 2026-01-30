<!--
  v24 — VR Offices: Desk IRC link (auto connect/reconnect, per-desk channel)

  This version focuses on wiring the existing `addons/irc_client` library into `vr_offices`
  so each desk can maintain a reliable IRC communication channel.
-->

# v24 — VR Offices Desk IRC Link

## Vision (this version)

When a player places a desk in VR Offices, that desk becomes a “ready” communication endpoint:

- Each desk maintains an IRC connection to a configured server.
- Each desk joins a deterministic, unique channel (per save + desk id).
- The desk auto-reconnects and auto-rejoins after disconnects.
- NPC/Gameplay code can treat the desk as a stable mailbox: send/receive messages via that channel.

Non-goals in v24:

- No new VR Offices UI for IRC config (use env vars for now).
- No gameplay interaction flow (NPC walking up to desk) yet; only the desk-side connectivity + API.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Parse IRC `005` ISUPPORT and expose limits | `IrcClient` exposes parsed ISUPPORT values used by higher layers | Run `tests/test_irc_isupport_parsing.gd` | todo |
| M2 | Desk IRC link component with auto connect/reconnect | New desk child node connects + joins per-desk channel using safe nick/channel lengths | Run `tests/test_vr_offices_irc_names.gd` and `tests/test_vr_offices_desk_irc_link_smoke.gd` | todo |

## Plan Index

- `docs/plan/v24-vr-offices-desk-irc-link.md`

## Known Gaps (end-of-version checklist)

- [ ] Decide where IRC config should live long-term (save state vs UI vs ProjectSettings).
- [ ] Expose a small gameplay API for NPCs to “use a desk” (send/receive) without knowing IRC details.
- [ ] Add join/ready detection based on JOIN/NAMES/366 for stronger readiness.

