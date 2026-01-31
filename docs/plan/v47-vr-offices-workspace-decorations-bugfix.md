# v47 Plan — VR Offices: Workspace Decorations Bugfix (Fit + Wall Alignment)

## Goal

Make Office Pack decoration props look reasonable in each workspace by correcting:

- Wall mount axis/offset (depth axis mismatch)
- Extreme source asset scale
- File cabinet facing

## Root Cause (observed)

Several Office Pack `.glb` assets have:

- Very large source units (e.g. analog clock / fire exit sign).
- “Depth” (thin axis) along **X** instead of **Z** for some wall props.

Our v46 wall alignment assumed the prop’s depth axis is Z and did no scaling, causing:

- Large translations away from wall (“floating” props).
- Visually huge props.

## Scope

- Implement per-asset fitting in `VrOfficesPropUtils`:
  - Optional rotate Y (to make depth axis Z).
  - Uniform scale to a target max dimension / target height.
- Add regression test that loads a subset of Office Pack assets in headless mode and asserts fitted bounds are within sane limits.

## Non-Goals

- No gameplay interaction changes.
- No per-workspace manual editing UI.

## Acceptance

- Analog clock and dartboard end up with small Z depth (mounted on wall, not floating far away).
- Whiteboard and fire exit sign are scaled down to reasonable size.
- Water cooler height is scaled down.
- Regression test passes in headless.

## Files

- Modify:
  - `vr_offices/core/props/VrOfficesPropUtils.gd`
- Add:
  - `tests/projects/vr_offices/test_vr_offices_workspace_decor_props_fit.gd`

## Steps (塔山开发循环)

1) **Red:** add `test_vr_offices_workspace_decor_props_fit.gd` asserting fitted bounds (max dimension / depth / height) for a few props.
2) **Red:** run the test; expect FAIL (no fitting applied).
3) **Green:** implement per-asset fitting in `VrOfficesPropUtils.gd` (rotate + scale) and allow spawning models in headless for this test.
4) **Green:** run the new test; expect PASS.
5) **Verify:** run `scripts/run_godot_tests.sh --suite vr_offices`.
6) **Docs:** update v47 index Evidence.

## Risks

- Import changes to the source assets could shift bounds slightly; keep test thresholds tolerant (avoid pixel-perfect values).

