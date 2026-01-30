# v20 Plan — Demo IRC (Defaults + Join Debugging)

## Goal

Make `demo_irc` work smoothly against typical plaintext IRC servers by default, and make join failures self-explanatory via on-screen diagnostics.

## Scope

- Change defaults:
  - TLS toggle defaults to off.
  - Port defaults to 6667.
- Normalize config on Connect/Join:
  - Require non-empty nick.
  - If user/realname empty: derive from nick.
  - If channel missing prefix: add `#`.
- Improve diagnostics in UI:
  - Show raw incoming lines (or at minimum: numerics + `ERROR`) in a subdued style.

## Non-Goals (v20)

- TLS support removal (still available via toggle).
- IRCv3, SASL.
- Deep state tracking (channel user list, etc.).

## Acceptance

1) **Defaults are correct**
- New config instances default to `port=6667` and `tls_enabled=false`.

2) **Normalization is deterministic**
- `normalize()` produces consistent results:
  - `user` and `realname` filled from `nick` when blank.
  - `channel` prefixed with `#` when it doesn't start with `#`, `&`, `+`, or `!`.

3) **Debuggability**
- When join fails due to server replies (e.g., not registered, no such channel, banned, etc.), the client displays the relevant numeric/error messages in the chat log.

## Files

Modify (v20):
- `demo_irc/DemoIrcConfig.gd`
- `demo_irc/Main.gd`
- `demo_irc/Main.tscn`

Create tests (v20):
- `tests/test_demo_irc_config_normalize.gd`

Docs (v20):
- `docs/plan/v20-index.md`
- `docs/plan/v20-demo-irc-defaults-and-join.md`

## Steps (塔山开发循环)

### 1) Red: config normalization test

- Add `tests/test_demo_irc_config_normalize.gd`:
  - Assert defaults.
  - Assert `normalize()` behavior for missing user/realname and missing channel prefix.
- Run headless; expect FAIL (no normalize / wrong defaults).

### 2) Green: implement config normalization + defaults

- Update `demo_irc/DemoIrcConfig.gd`:
  - Set defaults (port, tls).
  - Add `normalize()` and use it from `Main.gd` on Connect/Join.
- Re-run test; expect PASS.

### 3) Green: improve UI diagnostics

- Update `demo_irc/Main.gd`:
  - Show raw lines / numerics / `ERROR` in chat log.
  - Ensure nick is required before connecting.

### 4) Verify

- Run:
  - `tests/test_demo_irc_smoke.gd`
  - `tests/test_demo_irc_config_persistence.gd`
  - `tests/test_demo_irc_config_normalize.gd`

## Risks

- Logging raw lines with BBCode enabled: mitigate by escaping brackets so server text cannot be interpreted as BBCode.

