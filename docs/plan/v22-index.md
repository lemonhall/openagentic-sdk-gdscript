# v22 Index — Demo IRC (Timestamps)

## Vision (v22)

Make `demo_irc` logs easier to debug by prefixing all printed lines with a local time timestamp.

## Milestones (facts panel)

1. **Plan:** write an executable v22 plan with tests. (done)
2. **Formatter:** add a pure timestamp formatter helper. (done)
3. **UI:** prefix chat log lines with timestamps. (done)
4. **Tests:** regression test for timestamp formatting. (done)

## Plans (v22)

- `docs/plan/v22-demo-irc-timestamps.md`

## Definition of Done (DoD)

- Every line appended to the chat log is prefixed with `[HH:MM:SS]` (local system time).
- `tests/test_demo_irc_timestamp_format.gd` passes headless.

## Evidence

- Tests:
  - `tests/test_demo_irc_timestamp_format.gd` (PASS)
  - `tests/test_demo_irc_smoke.gd` (PASS)
  - `tests/test_demo_irc_config_persistence.gd` (PASS)
  - `tests/test_demo_irc_config_normalize.gd` (PASS)
  - `tests/test_demo_irc_bbcode_escape.gd` (PASS)

- Command (Linux Godot 4.6 headless):
  - `HOME=/tmp/oa-home-v22 XDG_DATA_HOME=/tmp/oa-xdg-data-v22 XDG_CONFIG_HOME=/tmp/oa-xdg-config-v22 /home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64 --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_demo_irc_timestamp_format.gd`
