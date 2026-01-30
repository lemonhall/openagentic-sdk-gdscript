# v30 — Desk IRC Indicator Polish

## Goal

Make the desk IRC indicator easier to see and more “gamey”, without changing its IRC status semantics.

## Scope

In scope:

- Raise the indicator a bit and make it slightly larger.
- Add a subtle idle animation: bobbing up/down + slow spin while visible.
- Update/extend existing indicator smoke test to lock the behavior.

Out of scope:

- Any new IRC state or persistence.
- Any new desk interaction UX.

## Acceptance

- `IrcIndicator` in `StandingDesk.tscn` has a higher Y offset and larger scale than before.
- While visible, `IrcIndicator.position.y` changes over time (bob).

## Files

- `vr_offices/furniture/StandingDesk.tscn`
- `vr_offices/furniture/DeskIrcIndicator.gd`
- `tests/test_vr_offices_desk_irc_indicator_smoke.gd`

## Steps (塔山开发循环)

### 1) Red

- Extend `tests/test_vr_offices_desk_irc_indicator_smoke.gd` to assert:
  - Indicator Y offset is above a minimum threshold.
  - Indicator scale is above a minimum threshold.
  - Indicator Y changes after a few frames (idle animation).

Run:

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_vr_offices_desk_irc_indicator_smoke.gd
```

### 2) Green

- Update `StandingDesk.tscn` indicator position/scale.
- Implement idle bob+spin in `DeskIrcIndicator.gd`.

### 3) Review

Re-run the same test, then a small VR Offices subset.

