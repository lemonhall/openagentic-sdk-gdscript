# v16 Plan (Sixth review) — Protocol Test Diversity & Edge Coverage

## Goal

Make v16 “classic IRC core” **more stable by testing it from more angles** (protocols are fragile):

- Stress the framing path with **random chunking** and **multi-line bursts**.
- Validate the “format → parse” pipeline with **deterministic random roundtrips**.
- Close protocol correctness gaps found in review (especially around **token validity**).

## Scope

- v16 only (core IRC behavior: parse/framing/wire formatting/registration/basic commands).
- In-memory peers only (CI/sandbox friendly).
- No new protocol features (TLS/CAP/SASL/IRCv3) unless required to fix correctness.

## Acceptance

1) **Framing robustness (random chunking)**
- Given a known set of IRC lines (ASCII + UTF-8), when bytes are split into random chunk sizes and fed through `IrcLineBuffer.push_bytes`, the recovered lines must match exactly (order + content).

2) **Wire correctness (reject invalid tokens)**
- `IrcWire.format_with_max_bytes` must **refuse** to emit a line when:
  - command/params contain internal whitespace (space/tab) or start with `:`.
  - command/params are empty after trimming.
- It must never “silently mutate” tokens (e.g. turning `"#a b"` into `"#ab"`).

3) **Roundtrip pipeline (deterministic fuzz)**
- For N deterministic pseudo-random generated messages (safe token set + mixed UTF-8 trailing):
  - `IrcWire.format(...)` → `IrcParser.parse_line(...)` must preserve `command/params/trailing`.

4) **Client burst/split integration**
- When the server sends multiple lines in a single inbound chunk (and also split across multiple reads), the client must:
  - emit `raw_line_received`/`message_received` for each line in order
  - respond to `PING` with `PONG` correctly

## Files

Add tests:
- `tests/test_irc_line_buffer_random_chunking.gd`
- `tests/test_irc_wire_reject_invalid_tokens.gd`
- `tests/test_irc_wire_parser_roundtrip_fuzz.gd`
- `tests/test_irc_client_burst_and_split.gd`

Modify code (as needed by Red tests):
- `addons/irc_client/IrcWire.gd`
- `addons/irc_client/IrcClient.gd` (only if a correctness gap is uncovered by tests)

Update index:
- `docs/plan/v16-index.md`

## Steps (塔山开发循环)

1) Red: add the tests above; run them to red (at least one should fail before code changes).
2) Green: implement minimal fixes to satisfy the tests.
3) Refactor: keep scripts small and responsibilities tight (~200 LOC self-review trigger).
4) Verify: run all `tests/test_irc_*.gd` with `timeout`.
5) Ship: commit + push.

