# v29 — StandingDesk Centering + Indicator Visibility

## Goal

Fix the regression where the desk GLB model drifts away from the desk’s clickable pick collider/IRC indicator, and make the gray indicator state readable at a glance.

## Scope

In scope:

- `StandingDesk.ensure_centered()` computes bounds from the `Model` subtree only (ignore indicator meshes).
- Preview visuals apply only to `Model` meshes (don’t touch indicator meshes).
- Improve default/disabled IRC indicator alpha (gray state).
- Add regression tests.

Out of scope:

- Persisting per-desk IRC logs.
- Changing desk collision gameplay/physics (this is click-pick only).

## Acceptance

- In a fresh `StandingDesk` instance, the desk model’s visual bounds center (XZ) is near the node origin after `_ready()`.
- The default IRC indicator albedo alpha is above a visibility threshold.

## Files

- `vr_offices/furniture/StandingDesk.gd`
- `vr_offices/furniture/DeskIrcIndicator.gd`
- `tests/test_vr_offices_standing_desk_centering.gd` (new)
- `tests/test_vr_offices_desk_irc_indicator_smoke.gd`

## Steps (塔山开发循环)

### 1) Red

- Add a regression test that instantiates `StandingDesk.tscn` and asserts the model visual bounds center (XZ) is near `(0,0)` in local space.
- Extend indicator smoke test to assert gray/unknown alpha is not near-invisible.

### 2) Green

- Update `StandingDesk.gd` to compute bounds using only the `Model` subtree.
- Update indicator default color alpha to be visible.

### 3) Review

Run:

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_vr_offices_standing_desk_centering.gd
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_vr_offices_desk_irc_indicator_smoke.gd
```

