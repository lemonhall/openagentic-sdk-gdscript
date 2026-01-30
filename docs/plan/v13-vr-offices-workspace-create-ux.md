# v13 Plan — VR Offices Workspace Create UX + Onboarding Hints

## Goal

Fix the workspace creation popup readability and add a short onboarding hint after creating a workspace so players can discover the workspace context menu (Shift + RMB).

## Scope

- Increase create popup width (and ensure it stays wide when centered).
- After a workspace is created, show an ActionHintOverlay message for ~10 seconds.
- Keep this hint “non-invasive”:
  - Only shown once per session (to avoid spamming during rapid creation).
  - If desk placement mode starts, placement hint should override and the post-create timer should not hide the placement hint.
- Update/extend tests to cover both behaviors.

## Acceptance

- `WorkspaceOverlay.prompt_create()` shows a popup with width ≥ 480 px.
- A successful workspace creation triggers `ActionHintOverlay.show_hint(...)`.
- Action hint auto-hides after ~10 seconds (unless replaced by another hint).

## Files

- Modify:
  - `vr_offices/ui/WorkspaceOverlay.tscn`
  - `vr_offices/ui/WorkspaceOverlay.gd`
  - `vr_offices/core/VrOfficesWorkspaceController.gd`
  - `tests/projects/vr_offices/test_vr_offices_workspace_overlay.gd`
- Add:
  - `tests/projects/vr_offices/test_vr_offices_workspace_create_onboarding_hint.gd`

## Steps (塔山开发循环)

1) **Red:** add test asserting create popup min width in `tests/projects/vr_offices/test_vr_offices_workspace_overlay.gd`.
2) **Red:** add a focused test that a workspace creation triggers an action hint.
3) **Green:** widen popup in `.tscn` and enforce size in `prompt_create()`.
4) **Green:** show 10s post-create hint from `VrOfficesWorkspaceController` after successful creation.
5) **Refactor:** keep strict-mode warnings clean; update v13 index evidence.
6) **Verify:** run Linux headless tests for VR Offices overlay + desks.

## Risks

- Popup sizing can vary by platform; enforce via `popup_centered(Vector2i(...))` and a testable minimum.
- Hint timers can race with other hints; mitigate via a generation/token guard.

