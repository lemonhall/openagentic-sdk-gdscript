<!--
  v33 — IRC reconnect robustness (initial connect failure + server ERROR)
-->

# v33 — IRC Reconnect Robustness

## Vision (this version)

- When auto-reconnect is enabled, the IRC client must recover even if the TCP connect fails **before** the first `connected` event.
- Server-sent `ERROR` disconnects must be treated as **remote** disconnects (still eligible for auto-reconnect), not as “user initiated”.
- The behavior is locked by tests so desks don’t get stuck in “connecting” or silently stop retrying.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Reconnect on pre-connected failure | A connect attempt that reaches `STATUS_ERROR/STATUS_NONE` before first `STATUS_CONNECTED` schedules retry | `tests/addons/irc_client/test_irc_reconnect_initial_connect_failure.gd` | todo |
| M2 | Reconnect after server `ERROR` | Server `ERROR` causes error+disconnect and schedules retry | `tests/addons/irc_client/test_irc_reconnect_after_server_error.gd` | todo |

## Plan Index

- `docs/plan/v33-irc-reconnect-robustness.md`

