# v25 — VR Offices IRC UI + Persistence

## Goal

Give VR Offices a friendly, in-world-consistent UI to configure IRC and verify desk connectivity.

## Scope

In scope:

- Persist IRC config in the existing `vr_offices` save file.
- Add `IrcOverlay` UI (style aligned with `DialogueOverlay`).
- Support “Test connect/join/send” inside the overlay.
- Show per-desk IRC status/logs.

Out of scope:

- Deep gameplay integration (NPC walks to desk and uses it).
- Persisting per-desk IRC logs (OK to keep in memory for now).

## Acceptance

- Config is saved and loaded per save slot.
- Overlay can be opened via a UI button (and a hotkey).
- Desk status list shows at least: desk_id, workspace_id, desired channel, status, ready.

## Files

Create / modify:

- `vr_offices/ui/VrOfficesUi.tscn`
- `vr_offices/ui/VrOfficesUi.gd`
- `vr_offices/ui/IrcOverlay.tscn` (new)
- `vr_offices/ui/IrcOverlay.gd` (new)
- `vr_offices/core/VrOfficesIrcSettings.gd` (new)
- `vr_offices/core/VrOfficesWorldState.gd`
- `vr_offices/core/VrOfficesSaveController.gd`
- `vr_offices/VrOffices.gd`
- `vr_offices/core/VrOfficesDeskManager.gd`
- `vr_offices/core/VrOfficesDeskIrcLink.gd`
- `vr_offices/core/VrOfficesIrcNames.gd`
- `vr_offices/furniture/StandingDesk.gd`

Tests:

- `tests/projects/vr_offices/test_vr_offices_irc_settings_persistence.gd` (new)
- `tests/projects/vr_offices/test_vr_offices_irc_overlay_smoke.gd` (new)
- Update `tests/projects/vr_offices/test_vr_offices_irc_names.gd` (channel meaning expectation)

## Steps (塔山开发循环)

### 1) TDD Red — write failing tests

1. Add persistence test for `state.irc`.
2. Add overlay smoke test (scene loads + overlay node exists).
3. Update names test to require “meaningful” channel format.

### 2) TDD Green — minimal implementation

- Add `VrOfficesIrcSettings` and wire into `SaveController` and `WorldState`.
- Add `IrcOverlay` scene and script.
- Add an “IRC…” button to `VrOfficesUi`.
- Update desk IRC naming and pass workspace_id to desk link.
- Add per-desk status/log surface for UI.

### 3) Review

Run:

```bash
export GODOT_LINUX_EXE=${GODOT_LINUX_EXE:-/home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64}
export HOME=/tmp/oa-home
export XDG_DATA_HOME=/tmp/oa-xdg-data
export XDG_CONFIG_HOME=/tmp/oa-xdg-config
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_irc_settings_persistence.gd
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_irc_overlay_smoke.gd
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_irc_names.gd
```

Then run full suite.

### 4) Ship

```bash
git status --porcelain=v1
git add -A
git commit -m "v25: vr_offices IRC settings UI"
git push
```

## Risks

- UI complexity: keep overlay minimal and reuse existing patterns.
- Avoid unexpected sockets: desk IRC remains opt-in, gated by saved config `enabled`.

