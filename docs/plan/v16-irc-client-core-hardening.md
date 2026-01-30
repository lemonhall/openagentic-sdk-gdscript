# v16 Plan (Third review) — IRC Core Hardening

## Goal

Make the v16 IRC client “扎实” at the protocol mechanics level (still core IRC / plain TCP):

- Correct under non-ideal TCP behavior (partial writes, arbitrary chunking).
- Defensive against malformed peers (oversized lines, never-ending streams without `\n`).
- RFC-style line length constraints enforced (512 bytes incl. `\r\n`).

## Scope

Within v16 (core IRC only):

- Transport I/O correctness:
  - Output write queue to support partial writes (`put_partial_data`).
  - Optional bounded queue to avoid unbounded memory growth.
- Line length limits:
  - Outgoing lines must not exceed 512 bytes including CRLF.
  - Incoming lines exceeding a safe limit are handled predictably (drop/error/close — pick one and test it).
- Bounded buffers:
  - Line buffer must not grow without bound if the peer never sends a newline.

Non-goals (still not v16):

- Reconnect/backoff, channel state, history persistence (v18).
- Real socket integration tests in CI (still sandbox constrained).

## Acceptance

1) **Partial-write safe output**
- Given a peer that only accepts N bytes per call (`put_partial_data`), sending a line eventually transmits the full bytes in-order after repeated `poll()` calls.

2) **Outgoing 512-byte constraint**
- For `PRIVMSG/NOTICE` with long trailing payload, client truncates the trailing (UTF-8 safe) so the resulting wire line is ≤ 510 bytes (plus CRLF).
- For messages that cannot fit even with empty trailing, client refuses to send and emits an error.

3) **Incoming safety limits**
- If the peer sends a line longer than a configured max without a newline, the client does not allocate unbounded memory; it fails fast (close connection and emit error).

## Files

Modify:
- `addons/irc_client/IrcClientTransport.gd`
- `addons/irc_client/IrcLineBuffer.gd`
- `addons/irc_client/IrcWire.gd`
- `addons/irc_client/IrcClient.gd` (only to surface errors if needed)
- `docs/plan/v16-index.md`

Add tests:
- `tests/addons/irc_client/test_irc_transport_partial_write.gd`
- `tests/addons/irc_client/test_irc_wire_max_len.gd`
- `tests/addons/irc_client/test_irc_line_buffer_limits.gd`

## Steps (塔山开发循环)

Slice A: partial writes
1) Red: `test_irc_transport_partial_write.gd` fails without write queue.
2) Green: implement output queue + flushing in `IrcClientTransport`.
3) Refactor: keep modules <200 LOC; keep errors observable.

Slice B: max line length
1) Red: `test_irc_wire_max_len.gd`.
2) Green: add `format_with_max_bytes(...)` and use it from `IrcClient`.

Slice C: buffer limits
1) Red: `test_irc_line_buffer_limits.gd`.
2) Green: add max buffer size enforcement and deterministic behavior on overflow.

## Risks

- UTF-8 safe truncation is subtle (must truncate by bytes without producing invalid UTF-8): mitigate with targeted tests.
- Behavior choice on oversized incoming lines (drop vs close) affects user experience: lock in one behavior and document it.

