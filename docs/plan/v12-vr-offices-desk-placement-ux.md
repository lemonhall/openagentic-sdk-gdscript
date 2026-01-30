# v12 Plan — VR Offices Desk Placement UX + RMB Conflict Fix

## Goal

Improve desk placement usability and restore “RMB move selected NPC” even when clicking inside a workspace, without removing the workspace RMB context menu.

## Scope

- Change placement-mode input:
  - RMB rotates (instead of canceling).
  - Esc cancels.
  - R rotates (same as RMB).
  - Rotation cycles through 0°/90°/180°/270°.
- Make ghost preview validity tint clearly visible (valid vs invalid).
- Fix RMB conflict:
  - If an NPC is selected, RMB click issues move (even if the ray hits a workspace collider).
  - Workspace context menu remains accessible via a modifier key (documented).
- Update docs:
  - `docs/vr_offices/controls.md`
  - `docs/vr_offices/controls.zh-CN.md`

## Non-Goals

- No grid snapping, no free-rotation, no multi-furniture types.
- No new UI for the workspace context menu.

## Acceptance

- In placement mode:
  - Pressing **R** rotates 90° each time, cycling through 4 orientations.
  - **RMB** rotates as well.
  - **Esc** cancels; RMB no longer cancels.
- With an NPC selected:
  - RMB clicking inside a workspace produces the same behavior as clicking the floor (move indicator appears, NPC moves).
  - Workspace menu is still reachable via a modifier key.
- Ghost preview tint is noticeably different between valid and invalid placement.

## Files

- Modify:
  - `vr_offices/core/VrOfficesInputController.gd`
  - `vr_offices/core/VrOfficesWorkspaceController.gd`
  - `vr_offices/furniture/StandingDesk.gd`
  - `docs/vr_offices/controls.md`
  - `docs/vr_offices/controls.zh-CN.md`
  - `tests/test_vr_offices_right_click_move.gd`

## Steps (塔山开发循环)

1) **Red:** extend `tests/test_vr_offices_right_click_move.gd` to reproduce the conflict:
   - Create a workspace.
   - RMB click inside the workspace.
   - Expect a move indicator (and no early consume by menu).
2) **Green:** adjust input routing in `VrOfficesInputController` so selected-NPC RMB move wins by default, while keeping a modifier to open the workspace menu.
3) **Green:** update placement-mode RMB to rotate and update rotation step logic to cycle.
4) **Green:** strengthen ghost preview validity tint in `StandingDesk.gd`.
5) **Refactor:** centralize rotation step helper, update docs.
6) **Verify:** run `scripts/run_godot_tests.sh` (or relevant subset).

## Risks

- Input priority changes may surprise users; mitigate by documenting the modifier behavior and keeping placement mode separate.
- Visual tint depends on Godot material overlay settings; ensure it’s visible in both headless tests (no-op) and in-editor play.

