# v91 index

Goal: auto-place meeting room props (table + screen + ceiling projector) using `assets/meeting_room/*.glb`, with size probing + tests.

## Artifacts

- PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-decorations.md`
- Plan: `docs/plan/v91-vr-offices-meeting-room-decorations.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Meeting room decoration wrappers + placement logic | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` | done |
| M2 | Full VR Offices regression suite | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` | done |

## Evidence

- 2026-02-07:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` → OK
