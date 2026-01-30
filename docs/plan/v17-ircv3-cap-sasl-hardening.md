# v17 Plan — IRCv3 CAP/SASL hardening (multiline + value caps + SASL chunking)

## Goal

Make the v17 IRCv3 “real world” flows robust against common server behaviors:

- `CAP LS` sent across multiple lines (the `*` continuation marker).
- Capability tokens carrying values (`sasl=PLAIN`, etc.) while the client requests by name (`sasl`).
- SASL PLAIN payload chunking (`AUTHENTICATE` max 400 chars per frame).

## Scope

- Improve CAP parsing/state machine to:
  - accumulate multiline `LS` / `ACK` / `NAK`
  - normalize capability names (strip `=...` suffix) for matching & acked list
- Improve SASL PLAIN to:
  - split base64 payload into 400-char chunks
  - append terminating `AUTHENTICATE +` when payload length is an exact multiple of 400

## Non-Goals

- Full SASL mechanisms beyond PLAIN.
- Full IRCv3 cap ecosystem (batch, labeled-response, etc.).
- Real socket TLS integration tests (still covered only by API-level tests in v17).

## Acceptance

- CAP: given multiline `CAP LS *` followed by final `CAP LS`, the client emits a single `CAP REQ` after the final `LS`.
- CAP: `sasl=PLAIN` advertised/acked still satisfies requested `sasl` and triggers SASL / CAP END correctly.
- SASL: long credentials produce multiple `AUTHENTICATE <chunk>` frames (<= 400 chars each), matching the expected base64 payload when concatenated.

## Files

- Add tests:
  - `tests/addons/irc_client/test_irc_client_cap_multiline_and_values.gd`
  - `tests/addons/irc_client/test_irc_client_sasl_plain_chunking.gd`
- Update implementation:
  - `addons/irc_client/IrcCapNegotiation.gd`
  - `addons/irc_client/IrcClientCap.gd`

## Steps (塔山开发循环)

1) **Red**
   - Run (expected fail):
     - `timeout 30s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/addons/irc_client/test_irc_client_cap_multiline_and_values.gd`
     - `timeout 30s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/addons/irc_client/test_irc_client_sasl_plain_chunking.gd`
2) **Green**
   - Implement CAP multiline + `=value` normalization.
   - Implement SASL 400-char chunking + terminating `AUTHENTICATE +` rule.
3) **Verify**
   - Run (expected pass):
     - `for t in tests/addons/irc_client/test_irc_*.gd; do echo "--- RUN $t"; timeout 30s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script "res://$t"; done`

## Risks

- CAP multiline behavior varies between servers; mitigate by handling `*` marker in a position-independent way (scan params after subcommand).
- SASL framing edge cases when payload is exactly 400n; mitigate with explicit terminating `AUTHENTICATE +` behavior and tests.

