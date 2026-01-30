# v19 Plan — Demo IRC (Standalone IRC Client UI)

## Goal

Add a new demo app `demo_irc/` that uses the existing `addons/irc_client/` plugin to provide a standalone IRC client UI for Godot 4.6, including a TLS connect toggle and persisted connection settings so iterative testing is fast.

## Scope

- New demo folder: `demo_irc/`
- Scene: `demo_irc/Main.tscn` (root `Control`)
- UI:
  - Connection form: host, port, TLS toggle, nick, user, realname, channel
  - Buttons: Connect, Disconnect, Join
  - Chat view: message log + input row (Enter to send)
- Client behaviors:
  - Create and own an `IrcClient` node.
  - Drive the client via `_process(dt)` calling `irc.poll(dt)`.
  - Connect using `connect_to` or `connect_to_tls`.
  - On message receive, render basic chat lines (minimum: `PRIVMSG`, plus some status like `JOIN/PART/NOTICE`).
  - Send text to the currently selected channel with `privmsg`.
- Persistence:
  - Auto-save on Connect and Join to `user://demo_irc/config.json`.
  - On startup, load config and restore form fields (but do not auto-connect/join).

## Non-Goals (v19)

- IRCv3: CAP negotiation, tags, message IDs.
- SASL authentication.
- CTCP beyond optional `/me` (ACTION).
- Robust slash-command parsing.
- Multi-channel UI, channel list, user list.
- Chat history persistence and search.

## Acceptance

1) **Scene & UI exists**
- `res://demo_irc/Main.tscn` loads and instantiates in headless test.
- The scene contains:
  - A connection form with the required fields.
  - A chat log and input row.

2) **Config persistence**
- Config can be saved and loaded under `user://demo_irc/config.json`.
- Startup restores fields from the last saved config.
- Clicking Connect or Join saves the latest values.

3) **IRC wiring**
- Client uses `addons/irc_client/IrcClient.gd`.
- TLS toggle chooses between `connect_to` and `connect_to_tls`.

## Files

Create (v19):
- `demo_irc/Main.tscn`
- `demo_irc/Main.gd`
- `demo_irc/DemoIrcConfig.gd`

Create tests (v19):
- `tests/test_demo_irc_smoke.gd`
- `tests/test_demo_irc_config_persistence.gd`

Modify (only if needed):
- `project.godot` (avoid; only if a project setting must be added for the new demo)

## Steps (塔山开发循环)

### 1) Red: demo smoke test

- Add `tests/test_demo_irc_smoke.gd`:
  - `load("res://demo_irc/Main.tscn")` exists and instantiates.
  - Assert key nodes exist (connection controls + chat controls).
- Run the test headless; expect FAIL (scene doesn’t exist yet).

### 2) Green: minimal scene + script

- Create `demo_irc/Main.tscn` + `demo_irc/Main.gd` with placeholder UI and minimal wiring so the smoke test passes.
- Re-run; expect PASS.

### 3) Red: config persistence test

- Add `tests/test_demo_irc_config_persistence.gd`:
  - Construct a config object, save, reload, assert values round-trip.
- Run; expect FAIL (config file/class not implemented).

### 4) Green: config save/load + auto-restore

- Implement `demo_irc/DemoIrcConfig.gd` with:
  - `load_from_user()` / `save_to_user()`
  - `to_dict()` / `from_dict()`
- Wire `Main.gd` to load at startup and save on Connect/Join.
- Re-run config persistence test; expect PASS.

### 5) Green: IRC connect + send/receive loop

- Wire `Main.gd` to:
  - Create `IrcClient` as a child node.
  - On Connect: set nick/user/realname; connect (TLS toggle).
  - On Join: join the channel.
  - On Send: send message to current channel.
  - Render basic received events to chat log.
- Re-run smoke + config tests; expect PASS.

### 6) Refactor: keep modules small

- Keep `Main.gd` focused on UI + glue code; keep config logic in `DemoIrcConfig.gd`.
- Ensure tests remain green.

### 7) Verify: minimal suite run

- Run `tests/test_demo_irc_*.gd` headless and record output in `docs/plan/v19-index.md` Evidence.

## Risks

- User data location differences under headless test runs: mitigate by keeping persistence small and using `HOME`/`XDG_*` overrides when running tests.
- IRC server behavior differences (welcome numerics, nick collision): keep v19 UX minimal; avoid over-specifying protocol states.

