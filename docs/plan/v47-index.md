<!--
  v47 — VR Offices: Workspace Decorations Bugfix (fit + wall alignment)
-->

# v47 — VR Offices: Workspace Decorations Bugfix (Fit + Wall Alignment)

## Vision (this version)

Fix obvious decoration placement/scale issues in VR Offices workspaces:

- Analog clock: no longer gigantic / floating in the room; properly wall-mounted.
- Dartboard: properly wall-mounted (not floating ~meters away).
- File cabinet: front faces the workspace center.
- Water cooler: scaled to a reasonable height (less “presence”).
- Whiteboard: visible + scaled to a reasonable size.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Prop fitting + alignment | Office Pack props are rotated/scaled/aligned consistently; regression test covers fitted bounds | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspace_decor_props_fit.gd` | done |

## Plan Index

- `docs/plan/v47-vr-offices-workspace-decorations-bugfix.md`

## Evidence

Green:

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspace_decor_props_fit.gd` (PASS)
- `scripts/run_godot_tests.sh --suite vr_offices` (PASS)
