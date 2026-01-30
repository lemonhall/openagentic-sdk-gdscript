# v19 Index — Demo IRC (Standalone IRC Client UI)

## Vision (v19)

Provide a small, standalone IRC client demo inside this repo, built on top of the existing `addons/irc_client/` plugin, with a simple but pleasant UI inspired by `vr_offices/ui` patterns.

Key behaviors:

- User can connect over plain TCP or TLS (toggle).
- User can join a channel and send messages.
- The demo remembers the last connection settings so repeated testing does not require re-entering fields.
- No auto-connect / auto-join on startup (only restore UI fields).

## Milestones (facts panel)

1. **Plan:** write an executable v19 plan with tests. (done)
2. **Scene/UI:** `demo_irc/Main.tscn` with connect + chat UI. (done)
3. **Persistence:** auto-save + restore config under `user://demo_irc/config.json`. (done)
4. **IRC wiring:** connect/disconnect/join/send/receive; TLS toggle supported. (done)
5. **Tests:** smoke + config persistence tests run headless. (done)

## Plans (v19)

- `docs/plan/v19-demo-irc.md`

## Definition of Done (DoD)

- A new scene `res://demo_irc/Main.tscn` can be instantiated in a headless test.
- The demo can connect via `IrcClient.connect_to(...)` or `IrcClient.connect_to_tls(...)` (runtime behavior).
- Connection UI fields are restored on startup from `user://demo_irc/config.json`, and are auto-saved when the user clicks Connect or Join.
- Tests:
  - `tests/projects/demo_irc/test_demo_irc_smoke.gd` passes.
  - `tests/projects/demo_irc/test_demo_irc_config_persistence.gd` passes.

## Evidence

- Tests (Linux Godot 4.6 headless):
  - `tests/projects/demo_irc/test_demo_irc_smoke.gd` (PASS)
  - `tests/projects/demo_irc/test_demo_irc_config_persistence.gd` (PASS)
- Command:
  - `HOME=/tmp/oa-home XDG_DATA_HOME=/tmp/oa-xdg-data XDG_CONFIG_HOME=/tmp/oa-xdg-config /home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64 --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/demo_irc/test_demo_irc_smoke.gd`

## Gaps (what is NOT implemented yet)

- IRCv3 / CAP / SASL.
- Multi-server / multi-channel management.
- Message history persistence beyond the last-used config.
- Advanced UI: user list, notifications, server raw log, slash command palette.
