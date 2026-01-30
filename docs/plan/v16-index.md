# v16 Index — IRC Client Plugin (Core IRC)

## Vision (v16)

Add a **pure GDScript** IRC client addon for **Godot 4.6** that can connect over plain TCP and support “traditional core IRC”:

- Parse and emit IRC messages correctly (`<prefix> <command> <params> :<trailing>`).
- Handle line framing (`\r\n`) and partial reads robustly.
- Support registration + basic chat workflows (NICK/USER, JOIN/PART, PRIVMSG/NOTICE).
- Handle keepalive (server PING → client PONG) and clean disconnects.

This version deliberately **does not** include TLS, IRCv3 CAP/SASL/tags, CTCP, multi-server, or persistence.

## Milestones (facts panel)

1. **Plan:** write an executable v16 plan with tests. (done)
2. **Parser:** IRC message parser + line buffer with unit tests. (done)
3. **Client:** connect/register + ping/pong loop with integration test. (done)
4. **Commands:** helpers for JOIN/PART/PRIVMSG/NOTICE + event signals. (done)
5. **Verify:** headless test run evidence. (done)
6. **Polish (v16 completeness):** byte-robust framing + wire formatting + clean disconnect API + addon packaging. (done)
7. **Hardening (v16 robustness):** partial-write safe output queue + line length limits + bounded buffers. (done)
8. **Classic completeness (v16):** PASS + registration idempotence + ERROR handling + USER realname fix. (done)
9. **Classic coverage (v16):** add explicit tests for JOIN/PART/PRIVMSG/NOTICE/QUIT and PING variants. (done)

## Plans (v16)

- `docs/plan/v16-irc-client-core.md`
- `docs/plan/v16-irc-client-core-polish.md`
- `docs/plan/v16-irc-client-core-hardening.md`
- `docs/plan/v16-irc-client-classic-completeness.md`
- `docs/plan/v16-irc-client-classic-coverage.md`

## Gap Review (Vision vs. Reality)

v16’s vision is “traditional core IRC over plain TCP”.

### Historical gaps (closed in second review)

- Framing robustness (byte-safe UTF-8 chunking).
- “message → wire” formatting as a single source of truth.
- Clean disconnect API.
- Standard plugin metadata + minimal usage docs.

### Second review (2026-01-30)

After closing the above gaps, v16 now matches its core vision and DoD, with one explicit constraint:

- **Core behaviors covered by tests:** parsing/framing, message emission formatting, QUIT/close API, and ping/pong loop are all regression-tested under `tests/test_irc_*.gd`.
- **Plain TCP is implemented but not socket-integration-tested in CI:** automated tests use an in-memory peer (sandbox friendly). Real-world TCP connection behavior is still exercised manually by users of the addon.

### Third review (2026-01-30)

Hardening focus (“扎实”):

- **Partial write safety:** output now uses a queue and supports `put_partial_data` peers.
- **Protocol line length safety:** outgoing formatting enforces a max byte budget (510 bytes before CRLF) with UTF-8 safe truncation of trailing payloads.
- **Bounded buffers:** incoming line buffering is bounded; overflow triggers transport close + client `error` + `disconnected`.

### Fourth review (2026-01-30)

Classic IRC completeness checks:

- **Registration correctness:** supports optional `PASS` (before `NICK/USER`) and avoids resending registration lines even when CAP completion causes repeated “ready to register” callbacks.
- **Server ERROR handling:** receiving `ERROR :...` emits `error` and closes the connection (emitting `disconnected`).

### Fifth review (2026-01-30)

Coverage focus:

- Add missing regression coverage for classic command helpers (`JOIN/PART/PRIVMSG/NOTICE/QUIT`) and PING edge forms.

## Definition of Done (DoD)

- Addon code lives under `addons/irc_client/` and is usable from game code via scripts/classes (pure GDScript).
- Tests exist and cover:
  - IRC message parsing edge-cases (prefix, params, trailing).
  - Line buffering with partial reads and multiple messages per chunk.
  - A minimal end-to-end loop using a scripted in-memory transport (client registers, responds to PING).
- No single `.gd` file becomes “god file”: if a file approaches ~200 LOC, split into smaller focused scripts.

## Verification

- WSL2 + Linux Godot:
  - Follow `AGENTS.md` “Running tests (WSL2 + Linux Godot)”.

## Evidence

- Tests:
  - `tests/test_irc_parser.gd`
  - `tests/test_irc_line_buffer.gd`
  - `tests/test_irc_client_integration.gd`
  - `tests/test_irc_wire_format.gd`
  - `tests/test_irc_disconnect.gd`
  - `tests/test_irc_transport_partial_write.gd`
  - `tests/test_irc_wire_max_len.gd`
  - `tests/test_irc_line_buffer_limits.gd`
  - `tests/test_irc_transport_overflow.gd`
  - `tests/test_irc_client_overflow_disconnect.gd`
  - `tests/test_irc_client_registration_order.gd`
  - `tests/test_irc_client_registration_idempotent.gd`
  - `tests/test_irc_client_user_realname.gd`
  - `tests/test_irc_client_server_error_disconnect.gd`
  - `tests/test_irc_client_basic_commands.gd`
  - `tests/test_irc_client_ping_pong_edges.gd`

- Last verification (Linux headless):
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_parser.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_line_buffer.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_client_integration.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_wire_format.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_disconnect.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_transport_partial_write.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_wire_max_len.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_line_buffer_limits.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_transport_overflow.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_client_overflow_disconnect.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_client_registration_order.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_client_registration_idempotent.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_client_user_realname.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_client_server_error_disconnect.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_client_basic_commands.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_client_ping_pong_edges.gd`
