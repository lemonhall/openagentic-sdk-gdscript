# v13 Index — VR Offices Workspace Create UX + Onboarding Hints

## Vision (v13)

Make workspace creation feel readable and self-explanatory:

- The “Create workspace” popup is wide enough that text isn’t clipped.
- After creating a workspace, show a short, temporary action hint that teaches how to open the workspace menu (Shift + RMB) so players can discover “Add Standing Desk…” and “Delete workspace”.

## Milestones (facts panel)

1. **Plan:** write an executable v13 plan with tests. (done)
2. **UI:** widen the workspace create popup. (done)
3. **Hints:** show a 10s post-create action hint (ActionHintOverlay). (done)
4. **Verify:** add/update tests and run headless suite. (done)

## Plans (v13)

- `docs/plan/v13-vr-offices-workspace-create-ux.md`

## Definition of Done (DoD)

- Workspace create popup width is increased (no obvious clipping with long strings).
- After a successful workspace creation, an action hint appears for ~10 seconds:
  - Teaches **Shift + Right Click** on a workspace to open the workspace menu.
  - Does not interfere with desk placement hints (placement hint wins).
- Tests cover:
  - Popup has a minimum width (regression).
  - Post-create hint triggers from workspace creation flow (regression).

## Verification

- WSL2 + Linux Godot (recommended):
  - Follow `AGENTS.md` “Running tests (WSL2 + Linux Godot)”.

## Evidence

- Tests:
  - `tests/projects/vr_offices/test_vr_offices_workspace_overlay.gd`
  - `tests/projects/vr_offices/test_vr_offices_workspace_create_onboarding_hint.gd`
