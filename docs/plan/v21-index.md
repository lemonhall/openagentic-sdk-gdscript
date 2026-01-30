# v21 Index — Demo IRC (BBCode Escaping Fix)

## Vision (v21)

When `demo_irc` shows numeric/error diagnostics in the chat log, brackets must render correctly (e.g. `[432] ...`) without leaking BBCode tokens like `[lb]`.

## Milestones (facts panel)

1. **Plan:** write an executable v21 plan with tests. (done)
2. **Test:** add a regression test for BBCode escaping. (done)
3. **Fix:** escape algorithm does not corrupt itself. (done)

## Plans (v21)

- `docs/plan/v21-demo-irc-bbcode-escape.md`

## Definition of Done (DoD)

- `tests/projects/demo_irc/test_demo_irc_bbcode_escape.gd` passes headless.
- Rendering of numeric/error lines uses a safe escape routine (no self-corruption).

## Evidence

- Tests:
  - `tests/projects/demo_irc/test_demo_irc_bbcode_escape.gd` (PASS)
  - `tests/projects/demo_irc/test_demo_irc_smoke.gd` (PASS)
  - `tests/projects/demo_irc/test_demo_irc_config_persistence.gd` (PASS)
  - `tests/projects/demo_irc/test_demo_irc_config_normalize.gd` (PASS)

- Command (Linux Godot 4.6 headless):
  - `HOME=/tmp/oa-home-v21 XDG_DATA_HOME=/tmp/oa-xdg-data-v21 XDG_CONFIG_HOME=/tmp/oa-xdg-config-v21 /home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64 --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/demo_irc/test_demo_irc_bbcode_escape.gd`
