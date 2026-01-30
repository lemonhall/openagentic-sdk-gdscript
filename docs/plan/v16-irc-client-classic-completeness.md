# v16 Plan (Fourth review) — Classic IRC Completeness

## Goal

Verify and close remaining gaps for “classic / traditional core IRC” behavior in v16:

- Registration correctness: `PASS` support, correct ordering, and idempotent registration (don’t spam `NICK/USER`).
- Correct `USER` realname behavior.
- Proper handling of server `ERROR` (surface error + disconnect).

## Scope (still v16)

- Core IRC only; no new IRCv3/TLS/CTCP requirements.
- Tests must use in-memory peers (no socket integration required).

## Acceptance

1) **PASS before NICK/USER**
- When password is configured, the first registration lines sent are:
  1. `PASS …`
  2. `NICK …`
  3. `USER …`

2) **Registration idempotence**
- Repeated `poll()` calls do not resend `PASS/NICK/USER` after they have been sent once for the current connection.

3) **USER realname correctness**
- `set_user(..., realname="Real Name")` actually sends `USER ... :Real Name`.

4) **Server ERROR handling**
- When receiving `ERROR :reason`, client emits `error` and then emits `disconnected` (closing the transport).

## Files

Modify:
- `addons/irc_client/IrcClient.gd`
- `docs/plan/v16-index.md`

Add tests:
- `tests/addons/irc_client/test_irc_client_registration_order.gd`
- `tests/addons/irc_client/test_irc_client_registration_idempotent.gd`
- `tests/addons/irc_client/test_irc_client_user_realname.gd`
- `tests/addons/irc_client/test_irc_client_server_error_disconnect.gd`

## Steps (塔山开发循环)

1) Red: add failing tests for PASS/order, idempotence, USER realname, and ERROR disconnect.
2) Green: implement the missing behaviors with minimal changes.
3) Refactor: keep scripts small and avoid extra responsibilities in `IrcClient`.
4) Verify: run all `tests/addons/irc_client/test_irc_*.gd` with timeouts; record evidence in `v16-index`.

