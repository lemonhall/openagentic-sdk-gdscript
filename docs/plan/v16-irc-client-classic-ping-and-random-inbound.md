# v16 Plan (Eighth review) — Classic PING Semantics + Random Inbound Chunking

## Goal

Strengthen v16 classic IRC correctness and test diversity by:

1) Fixing classic **PING/PONG multi-parameter semantics** (`PING a b` → `PONG a b`).
2) Adding a client-level **random inbound chunking** test (TCP fragmentation simulator).
3) Improving parser robustness by tolerating **leading spaces** (defensive input handling).

## Scope

- v16 only (no new IRCv3 features).
- In-memory peers only.

## Acceptance

1) **PING multi-param correctness**
- `PING a b` yields `PONG a b`
- `PING a b c` yields `PONG a b c` (best-effort: mirror all params)
- Existing PING shapes remain correct (`PING :t`, `PING t`, `PING`)

2) **Random inbound chunking**
- Given a known list of inbound lines, split the wire bytes into deterministic random chunks.
- Client must emit all raw lines in order and produce the expected PONG replies.

3) **Parser leading spaces tolerance**
- `parse_line("  PING :abc")` parses as command `PING` with trailing `abc`.

## Files

Add tests:
- `tests/addons/irc_client/test_irc_client_random_inbound_chunking.gd`
- `tests/addons/irc_client/test_irc_parser_leading_spaces.gd`

Modify tests:
- `tests/addons/irc_client/test_irc_client_ping_pong_edges.gd`

Modify code:
- `addons/irc_client/IrcClientPing.gd`
- `addons/irc_client/IrcParser.gd`

Update index:
- `docs/plan/v16-index.md`

## Steps (塔山开发循环)

1) Red: add the tests above; run them to red.
2) Green: minimal fixes (PING params join, parser leading-space skip).
3) Verify: run all `tests/addons/irc_client/test_irc_*.gd` with `timeout`.
4) Ship: commit + push.

