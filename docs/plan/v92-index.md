# v92 index

Goal: add Meeting Room microphone + always-on indicator + table collision, and open a dedicated meeting-room group chat overlay on mic double-click (no skills UI).

## Artifacts

- PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-mic-group-chat.md`
- Plan: `docs/plan/v92-vr-offices-meeting-room-mic-group-chat.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Mic prop + indicator + table collision wrappers | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` | done |
| M2 | Double-click mic opens meeting room overlay | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_mic_double_click_opens_overlay.gd` | done |
| M3 | Full VR Offices regression suite | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` | done |

## Traceability

| Req ID | Plan | Tests / Verify | Evidence |
|---|---|---|---|
| REQ-001 | v92 | `tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` | `-Suite vr_offices` OK |
| REQ-002 | v92 | `tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` | `-Suite vr_offices` OK |
| REQ-003 | v92 | `tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` | `-Suite vr_offices` OK |
| REQ-004 | v92 | `tests/projects/vr_offices/test_vr_offices_meeting_mic_double_click_opens_overlay.gd` | `-Suite vr_offices` OK |
| REQ-005 | v92 | `scripts/run_godot_tests.ps1 -Suite vr_offices` | `-Suite vr_offices` OK |

## Evidence

- 2026-02-07:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` → OK

## Gaps / Follow-ups

- Visual layout tuning for mic placement (final art polish).
- Group chat semantics (participants, “who speaks”, meeting roles) not implemented by design.

