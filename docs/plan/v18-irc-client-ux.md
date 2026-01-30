# v18 Plan — IRC Client Plugin (Reconnect/State/CTCP/History)

## Goal

Add the “client experience” layer on top of v16/v17: reconnection, state management, CTCP conveniences, and optional chat history persistence.

## Scope (v18)

- Reconnect/backoff policy and deterministic rejoin behavior.
- Multi-channel state (at minimum: joined channels list; optionally topic + user list as a later slice).
- CTCP:
  - Outgoing `/me` (ACTION).
  - Incoming ACTION as a structured event.
  - CTCP VERSION and CTCP PING.
- Optional local history logging to `user://` (opt-in; bounded size).

## Acceptance (high-level)

- Tests cover reconnect/backoff and rejoin sequencing without relying on real internet servers.
- Tests cover CTCP encode/decode for ACTION/VERSION/PING.
- History persistence writes only under `user://` and is path-safe.

## Steps (塔山开发循环)

- Start with reconnect unit tests and a fake/scripted server harness.
- Add CTCP tests next.
- Add history last (opt-in, bounded, safe).
