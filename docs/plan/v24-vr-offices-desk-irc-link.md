# v24 — VR Offices Desk IRC Link

## Goal

Make each desk instance in `vr_offices` keep an IRC communication channel alive:

- Auto connect on spawn (when enabled via env).
- Auto reconnect (with backoff) and auto rejoin the desk’s channel.
- Use deterministic, server-safe nick/channel names derived from `save_id` + `desk_id`.
- Expose minimal “ready” state and message send/receive surface for future NPC use.

## Scope

In scope:

- Add IRC `005` ISUPPORT parsing in `addons/irc_client` so higher layers can read `NICKLEN` / `CHANNELLEN`.
- Add `vr_offices` helper to derive safe nick/channel names with length caps.
- Attach a small IRC link node under each spawned desk (opt-in via env vars).

Out of scope:

- VR Offices UI changes.
- NPC interaction behavior changes.
- Server-side AI bot implementation.

## Acceptance

- `IrcClient` can parse and expose `NICKLEN` and `CHANNELLEN` from `005` lines.
- `vr_offices` can derive nick/channel strings that:
  - Always start with valid prefixes (`nick` starts with `oa`, channel starts with `#`).
  - Respect provided `nicklen`/`channellen` caps.
  - Stay deterministic for the same inputs.
- A new desk child node can be created and configured (without networking) in a smoke test.

## Files

Create / modify:

- `addons/irc_client/IrcClientInbound.gd`
- `addons/irc_client/IrcClientCoreEngine.gd`
- `addons/irc_client/IrcClientCore.gd`
- `addons/irc_client/IrcClient.gd`
- `addons/irc_client/IrcClientServerInfo.gd` (new)
- `vr_offices/core/VrOfficesDeskManager.gd`
- `vr_offices/VrOffices.gd`
- `vr_offices/core/VrOfficesIrcConfig.gd` (new)
- `vr_offices/core/VrOfficesIrcNames.gd` (new)
- `vr_offices/core/VrOfficesDeskIrcLink.gd` (new)

Tests:

- `tests/test_irc_isupport_parsing.gd` (new)
- `tests/test_vr_offices_irc_names.gd` (new)
- `tests/test_vr_offices_desk_irc_link_smoke.gd` (new)

## Steps (塔山开发循环)

### 1) TDD Red — write failing tests

1. Add `tests/test_irc_isupport_parsing.gd` asserting `CHANNELLEN`/`NICKLEN` extracted from a `005` line.
2. Add `tests/test_vr_offices_irc_names.gd` asserting derived nick/channel respect caps.
3. Add `tests/test_vr_offices_desk_irc_link_smoke.gd` asserting the link node can be instantiated and configured.

Run (expect failures due to missing files/methods):

```bash
export GODOT_LINUX_EXE=${GODOT_LINUX_EXE:-/home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64}
export HOME=/tmp/oa-home
export XDG_DATA_HOME=/tmp/oa-xdg-data
export XDG_CONFIG_HOME=/tmp/oa-xdg-config
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_irc_isupport_parsing.gd
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_vr_offices_irc_names.gd
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_vr_offices_desk_irc_link_smoke.gd
```

### 2) TDD Green — minimal implementation

- Implement `IrcClientServerInfo.gd` and wire it into inbound/engine.
- Expose `get_isupport()` (and small helpers) on `IrcClient`.
- Implement `VrOfficesIrcNames.gd` and `VrOfficesDeskIrcLink.gd`.
- Attach the link node in `VrOfficesDeskManager._spawn_node_for` (opt-in).

Re-run the same commands and expect pass.

### 3) Refactor (keep it small)

- Keep each new `.gd` file narrowly scoped (<~200 LOC).
- Avoid adding VR Offices UI at this stage.

### 4) Review

- Run full suite:

```bash
for t in tests/test_*.gd; do
  echo "--- RUN $t"
  timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script "res://$t"
done
```

### 5) Ship

```bash
git status --porcelain=v1
git add -A
git commit -m "v24: vr_offices desk IRC link"
git push
```

## Risks

- ISUPPORT parsing variance across servers (tokens may differ); keep parsing tolerant.
- Multiple desk connections could be heavy; keep it opt-in and revisit pooling later.
- Headless tests don’t open sockets; keep desk link test strictly non-networked.

