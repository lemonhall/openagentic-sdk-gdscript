# v18 Index — IRC Client Plugin (Client UX + CTCP + Persistence)

## Vision (v18)

Turn the v16/v17 “protocol-capable client” into a practical in-game chat component:

- Automatic reconnect with backoff and re-join.
- Multi-server / multi-channel state management.
- CTCP support (`/me`, `VERSION`, CTCP `PING`).
- Optional local logging/history (client-side persistence).

## Milestones (facts panel)

1. **Plan:** write an executable v18 plan with tests. (done)
2. **Reconnect:** disconnect detection + reconnect/backoff + tests. (todo)
3. **State:** channel/user/topic tracking API + tests. (todo)
4. **CTCP:** ACTION, VERSION, PING + tests. (doing — ACTION done; VERSION/PING todo)
5. **History:** optional local log persistence + tests. (todo)

## Plans (v18)

- `docs/plan/v18-irc-client-ux.md`

## Definition of Done (DoD)

- Client can recover from a forced disconnect and resume (reconnect + re-register + re-join) deterministically in tests.
- CTCP `/me` produces ACTION messages and incoming ACTION is parsed into an event.
- Optional history logger stores plain text logs safely (no secrets).

## Evidence

- Tests:
  - `tests/test_irc_ctcp_action.gd`

## Gaps (what is NOT implemented yet)

- Reconnect/backoff + deterministic re-register + re-join (no implementation, no tests yet).
- Multi-server/multi-channel state management API (no implementation, no tests yet).
- CTCP VERSION + CTCP PING encode/decode (only ACTION is implemented + tested).
- Optional local history persistence under `user://` (no implementation, no tests yet).
