# v20 Index — Demo IRC (Defaults + Join Debugging)

## Vision (v20)

Improve the `demo_irc/` UX for rapid local testing against classic IRC servers that do not support TLS by default, and make join failures diagnosable without external tooling.

Key behaviors:

- Default: TLS disabled; default port 6667.
- Connection always sends `NICK` and `USER` (derive defaults from nick if user/realname are blank).
- Join uses a normalized channel name (`#` prefix when missing).
- The chat log shows relevant server responses (numerics / `ERROR`) so failures are visible.

## Milestones (facts panel)

1. **Plan:** write an executable v20 plan with tests. (done)
2. **Defaults:** TLS off + port 6667 defaults. (done)
3. **Normalization:** derive user/realname, normalize channel. (done)
4. **Diagnostics:** show numeric/errors in UI. (done)
5. **Tests:** normalization + defaults tests run headless. (done)

## Plans (v20)

- `docs/plan/v20-demo-irc-defaults-and-join.md`

## Definition of Done (DoD)

- `DemoIrcConfig` defaults to `port=6667` and `tls_enabled=false`.
- `DemoIrcConfig.normalize()`:
  - Fills `user`/`realname` from `nick` when blank.
  - Adds `#` to `channel` when missing a standard prefix.
- `tests/projects/demo_irc/test_demo_irc_config_normalize.gd` passes headless.

## Evidence

- Tests:
  - `tests/projects/demo_irc/test_demo_irc_config_normalize.gd` (PASS)
  - `tests/projects/demo_irc/test_demo_irc_smoke.gd` (PASS)
  - `tests/projects/demo_irc/test_demo_irc_config_persistence.gd` (PASS)
 
- Command (Linux Godot 4.6 headless):
  - `HOME=/tmp/oa-home-v20b XDG_DATA_HOME=/tmp/oa-xdg-data-v20b XDG_CONFIG_HOME=/tmp/oa-xdg-config-v20b /home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64 --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/demo_irc/test_demo_irc_config_normalize.gd`
