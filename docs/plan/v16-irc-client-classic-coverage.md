# v16 Plan (Fifth review) — Classic IRC Coverage

## Goal

Treat “classic IRC completeness” as a set of executable, regression-tested behaviors.

This fifth review adds tests for the remaining classic core command surface that was implemented but not explicitly covered:

- `JOIN`, `PART`, `PRIVMSG`, `NOTICE`, `QUIT` outbound formatting (including max line length enforcement).
- `PING` inbound variants (`PING :trail`, `PING param`, `PING`) → correct `PONG` responses.
- PASS idempotence together with CAP-driven registration callbacks.

## Scope

- v16 only (core IRC behavior and helpers).
- No protocol expansions beyond v16.
- In-memory peers only (CI/sandbox friendly).

## Acceptance

1) **Command helper wire correctness**
- Calling the helpers produces the exact expected wire lines (CRLF terminated).
- `PRIVMSG`/`NOTICE` payloads respect the 512-byte limit (including CRLF) via truncation.

2) **PING variants**
- Each PING shape yields the correct PONG shape:
  - `PING :abc` → `PONG :abc`
  - `PING abc` → `PONG abc`
  - `PING` → `PONG`

3) **PASS idempotence**
- With `set_password` + CAP negotiation, `PASS` is sent exactly once.

## Files

Add tests:
- `tests/addons/irc_client/test_irc_client_basic_commands.gd`
- `tests/addons/irc_client/test_irc_client_ping_pong_edges.gd`

Modify tests:
- `tests/addons/irc_client/test_irc_client_registration_idempotent.gd` (also asserts PASS once)

Update index:
- `docs/plan/v16-index.md`

## Steps (塔山开发循环)

1) Red: add the above tests; run them.
2) Green: fix any discovered gaps with minimal changes.
3) Verify: run full `tests/addons/irc_client/test_irc_*.gd` with `timeout`.
4) Ship: commit + push.

