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

## Plans (v16)

- `docs/plan/v16-irc-client-core.md`

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

- Last verification (Linux headless):
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_parser.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_line_buffer.gd`
  - `timeout 20s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_client_integration.gd`
