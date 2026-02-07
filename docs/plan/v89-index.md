# v89 index

Goal: add Meeting Rooms as a second “room type” created by rectangle-drag, with context-menu delete + persistence + tests.

## Artifacts

- PRD: `docs/prd/2026-02-07-vr-offices-meeting-rooms.md`
- Plan: `docs/plan/v89-vr-offices-meeting-rooms.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Meeting room model/store + persistence | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_rooms_persistence.gd` | done |
| M2 | Meeting room nodes + delete | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` | done |
| M3 | UX: create (type choice) + context menu delete | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_workspace_overlay.gd` | done |

## Evidence

- 2026-02-07:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` → OK
