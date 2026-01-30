# v16 Plan — IRC Client Plugin (Core IRC, No IRCv3/TLS)

## Goal

Ship a Godot 4.6 addon under `addons/irc_client/` that implements a usable core IRC client in pure GDScript, with tests proving correctness of parsing + framing + a minimal connect/register/ping loop.

## Scope

- Traditional IRC (core):
  - IRC message parsing/formatting.
  - Line framing: `\r\n` separated messages; robust handling of partial reads.
  - Plain TCP connection via Godot networking (`StreamPeerTCP`).
  - Registration commands: `NICK`, `USER`.
  - Basic channel + messaging: `JOIN`, `PART`, `PRIVMSG`, `NOTICE`.
  - Keepalive: handle server `PING` by replying `PONG`.
  - Surface events via signals/callbacks (received message, connected, disconnected, errors).
- Engineering constraints:
  - Keep scripts small; target <200 LOC per `.gd`.
  - Separate pure parsing logic from transport so parsing is fully testable without network.

## Non-Goals (v16)

- TLS.
- IRCv3 capabilities (`CAP`), message tags, SASL authentication.
- CTCP (`/me`, `VERSION`, etc.).
- Multi-server/multi-connection manager.
- Persistence: chat history, message IDs, reconnection state machine.

## Acceptance

1) **Parser correctness**
- Given raw IRC lines, parser outputs `{prefix, command, params, trailing}` (or equivalent struct) consistent with RFC-style grammar:
  - Prefix optional.
  - Trailing is optional and may contain spaces.
  - Params split on spaces until the first `:` (trailing marker).

2) **Line buffering**
- Given chunked TCP reads (arbitrary splits), line buffer yields complete lines exactly once, and never drops bytes.
- Handles:
  - Multiple messages in one chunk.
  - A message split across multiple chunks.
  - Optional `\r\n` vs `\n` handling policy (pick one and enforce in tests; prefer strict `\r\n` but tolerate lone `\n`).

3) **Minimal integration**
- In a headless test, a scripted in-memory transport can:
  - Observe the client sending `NICK` and `USER`.
  - Inject `PING :token` and observe a matching `PONG :token`.

## Files

Create (v16):
- `addons/irc_client/IrcClient.gd`
- `addons/irc_client/IrcMessage.gd` (data container / helper)
- `addons/irc_client/IrcParser.gd`
- `addons/irc_client/IrcLineBuffer.gd`
- `addons/irc_client/IrcWire.gd` (format/send helpers; optional)
- `addons/irc_client/README.md`

Create tests (v16):
- `tests/addons/irc_client/test_irc_parser.gd`
- `tests/addons/irc_client/test_irc_line_buffer.gd`
- `tests/addons/irc_client/test_irc_client_integration.gd`

Modify (only if needed for test harness consistency):
- `AGENTS.md` (only for test running notes; avoid churn)

## Steps (塔山开发循环)

### 1) Red: parser tests

- Add `tests/addons/irc_client/test_irc_parser.gd` with cases:
  - `PING :abc`
  - `:nick!user@host PRIVMSG #chan :hello world`
  - `:server 001 nick :Welcome`
  - `JOIN #chan`
  - A line with multiple middle params + trailing
- Run the single test script headless; expect FAIL because parser doesn’t exist.

### 2) Green: minimal parser

- Implement `addons/irc_client/IrcParser.gd` + `IrcMessage.gd` with only what’s needed to pass tests.
- Re-run parser test; expect PASS.

### 3) Red: line buffer tests

- Add `tests/addons/irc_client/test_irc_line_buffer.gd`:
  - Feed chunks like `["PING :a", "bc\r\n"]` → yields one line `PING :abc`
  - Feed `["A\r\nB\r\n"]` → yields `A`, `B`
  - Feed `["A\nB\n"]` if we choose to tolerate lone `\n` (decide and encode)
- Run; expect FAIL.

### 4) Green: line buffer implementation

- Implement `addons/irc_client/IrcLineBuffer.gd` with a minimal API (e.g. `push_chunk(bytes_or_string) -> Array[String]`).
- Re-run; expect PASS.

### 5) Red: integration test with local TCPServer

- Add `tests/addons/irc_client/test_irc_client_integration.gd`:
  - Create `IrcClient` and a fake/scripted peer (in-memory).
  - Drive `poll()` for a bounded number of frames.
  - Assert client emits `NICK` and `USER` lines to the peer.
  - Inject `PING :t`; assert client emits `PONG :t`.
- Run; expect FAIL (client not implemented).

### 6) Green: minimal client transport + ping/pong

- Implement `addons/irc_client/IrcClient.gd`:
  - Use `StreamPeerTCP` connect/poll/read.
  - Use `IrcLineBuffer` + `IrcParser` to emit received messages.
  - Auto-respond to `PING` with `PONG` (minimal keepalive).
  - Implement `send_raw_line()` and helpers for `nick()`, `user()`, `join()`, `part()`, `privmsg()`, `notice()`.
- Re-run integration test; expect PASS.

### 7) Refactor: keep scripts small

- If any `.gd` approaches ~200 LOC, split responsibilities:
  - Parser vs line buffer vs transport vs command helpers.
- Keep tests unchanged and still passing.

### 8) Verify: suite run

- Run all `tests/addons/irc_client/test_*.gd` headless (Linux Godot recommended) and record evidence in `docs/plan/v16-index.md` (Evidence section).

## Risks

- Godot headless networking quirks: mitigate by using localhost `TCPServer` and bounded frame loops with timeouts.
- Message parsing edge-cases: mitigate by expanding parser tests early (Red) rather than discovering later via manual testing.
