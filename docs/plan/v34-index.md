<!--
  v34 — VR Offices: Desk IRC stability + disk logs
-->

# v34 — Desk IRC Stability + Disk Logs

## Vision (this version)

- Desks should not randomly flip to “connecting” just because the IRC overlay is opened/closed.
- Desk IRC traffic/state should be inspectable from disk (`user://`) for debugging.
- The behavior is locked by tests (no accidental reconnect storms).

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | No reconnect on irrelevant config | Changing test-only fields (nick/channel) or re-saving the same config must not reconfigure desk links | `tests/test_vr_offices_desk_manager_irc_config_stability.gd` | todo |
| M2 | Desk IRC disk logs | Each desk writes a bounded debug log to `user://openagentic/saves/<save_id>/vr_offices/desks/<desk_id>/irc.log` and exposes the path in snapshots | `tests/test_vr_offices_desk_irc_disk_log_smoke.gd` | todo |

## Plan Index

- `docs/plan/v34-desk-irc-stability-and-disk-logs.md`

