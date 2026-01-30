# v16 Plan (Seventh review) — Classic IRC Edge Cases & Hardening Tests

## Goal

Close remaining “classic IRC core” correctness gaps found in review, and add regression coverage from multiple angles.

This round focuses on two protocol-adjacent risks:

1) **Empty trailing parameter semantics** (e.g. `PRIVMSG #c :` is valid and distinct from `PRIVMSG #c`)
2) **Robustness under partial-write backpressure** (avoid recursion in write flushing)

## Scope

- v16 only.
- No new IRC features outside v16 vision.
- In-memory peers only.

## Acceptance

1) **Wire supports forced empty trailing**
- `IrcWire.format_with_max_bytes(..., force_trailing=true)` emits `CMD ... :` even when `trailing == ""`.
- Default behavior remains unchanged (no trailing marker when `force_trailing=false` and trailing empty).

2) **Client helpers preserve protocol semantics**
- `IrcClient.privmsg(target, "")` emits `PRIVMSG <target> :` (not `PRIVMSG <target>`).
- `IrcClient.notice(target, "")` emits `NOTICE <target> :`.

3) **No CRLF injection via trailing**
- Attempted `\r\n` injection inside trailing never creates extra wire lines.

4) **Transport flush is iterative**
- `IrcClientTransport` write flushing no longer uses recursion under `put_partial_data` peers.

## Files

Modify:
- `addons/irc_client/IrcWire.gd`
- `addons/irc_client/IrcClient.gd`
- `addons/irc_client/IrcClientTransport.gd`

Modify tests:
- `tests/test_irc_wire_format.gd`
- `tests/test_irc_client_basic_commands.gd`
- `tests/test_irc_transport_partial_write.gd`

Update index:
- `docs/plan/v16-index.md`

## Steps (塔山开发循环)

1) Red: add failing tests for empty trailing + injection + multi-line partial writes.
2) Green: minimal implementation changes to pass.
3) Refactor: make transport flushing iterative; keep behavior identical; keep scripts small.
4) Verify: run all `tests/test_irc_*.gd` with `timeout`.
5) Ship: commit + push.

