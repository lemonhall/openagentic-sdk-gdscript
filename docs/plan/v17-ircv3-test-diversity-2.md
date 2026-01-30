# v17 Plan — IRCv3 test diversity (CAP odd formats + SASL failure + tag escapes)

## Goal

Increase confidence in v17’s IRCv3 behavior by adding diverse tests for protocol “shapes” seen in the wild, beyond the happy path.

## Scope

- CAP:
  - Support capability lists that arrive as **non-trailing params** (no `:`), e.g. `CAP * LS * sasl=PLAIN message-tags`.
  - Verify registration behavior when CAP is disabled or when no caps are requested.
  - Verify behavior when server NAKs requested caps (should still `CAP END` and proceed).
- SASL:
  - Verify failure numerics (904–907) still end CAP and proceed to registration.
- Tags:
  - Verify all defined unescape sequences: `\\:` `\\s` `\\r` `\\n` `\\\\`.
  - Verify unknown escapes are preserved best-effort.

## Non-Goals

- Full IRCv3 feature coverage beyond CAP/SASL/tags.
- Network integration tests (still unit/in-memory only).

## Acceptance

- New tests cover the cases above and are **hang-proof** (deadlines + Godot headless `timeout`).
- Full IRC suite `tests/test_irc_*.gd` passes.

## Files

- Add tests:
  - `tests/test_irc_client_cap_ls_without_trailing_colon.gd`
  - `tests/test_irc_client_cap_disabled_registers.gd`
  - `tests/test_irc_client_cap_nak_still_registers.gd`
  - `tests/test_irc_client_sasl_failure_ends_cap.gd`
  - `tests/test_irc_parser_tags_escapes.gd`
- Update code (as required by failing tests):
  - `addons/irc_client/IrcCapNegotiation.gd`

## Steps (塔山开发循环)

1) **Red:** add tests above; run each headless with a `timeout` and confirm failures are meaningful.
2) **Green:** implement minimal fixes (primarily CAP list extraction without trailing).
3) **Refactor:** keep scripts small (~200 LOC self-review), keep parsing logic contained.
4) **Verify:** run full suite:
   - `for t in tests/test_irc_*.gd; do echo "--- RUN $t"; timeout 30s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script "res://$t"; done`
5) **Ship:** update `docs/plan/v17-index.md`, commit, push.

## Risks

- CAP grammar variations across servers; mitigate with tolerant parsing that prefers trailing but falls back to params.
- Test hangs; mitigate with strict deadlines and `timeout` per test.

