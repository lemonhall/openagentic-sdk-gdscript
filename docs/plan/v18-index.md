# v18 Index — IRC Client Plugin (Client UX + CTCP + Persistence)

## Vision (v18)

Turn the v16/v17 “protocol-capable client” into a practical in-game chat component:

- Automatic reconnect with backoff and re-join.
- (Deferred) Multi-server / multi-channel state management.
- (Deferred) CTCP support (`/me`, `VERSION`, CTCP `PING`).
- (Deferred) Optional local logging/history (client-side persistence).

## Milestones (facts panel)

1. **Plan:** write an executable v18 plan with tests. (done)
2. **Reconnect:** disconnect detection + reconnect/backoff + deterministic re-register + re-join + tests. (done)
3. **State:** channel/user/topic tracking API + tests. (deferred)
4. **CTCP:** ACTION, VERSION, PING + tests. (deferred — ACTION exists)
5. **History:** optional local log persistence + tests. (deferred)

## Plans (v18)

- `docs/plan/v18-irc-client-ux.md`
- `docs/plan/v18-irc-client-reconnect.md`

## Definition of Done (DoD)

- Client can recover from a forced disconnect and resume (reconnect + re-register + re-join) deterministically in tests.

## Evidence

- Tests:
  - `tests/test_irc_ctcp_action.gd`
  - `tests/test_irc_reconnect_rejoin.gd`

## Gaps (what is NOT implemented yet)

- Multi-server/multi-channel state management API (no implementation, no tests yet).
- CTCP VERSION + CTCP PING encode/decode (only ACTION is implemented + tested).
- Optional local history persistence under `user://` (no implementation, no tests yet).
