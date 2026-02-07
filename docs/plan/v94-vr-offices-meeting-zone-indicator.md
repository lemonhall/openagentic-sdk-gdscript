# v94 — VR Offices: Meeting zone indicator + meeting-state reliability

PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md`

## Problem

In manual playtests, commanding an NPC near the meeting table could still result in the old “waiting for work” timer re-enabling wandering after ~60 seconds, making it unclear whether the NPC was actually “in the meeting”. Also, the meeting distance check should respect the stretched/scaled meeting table footprint.

## Scope

- If an NPC becomes meeting-bound at move-to completion, suppress the default waiting-for-work timer so it won’t start wandering later.
- Compute meeting proximity based on the actual `TableCollision` box footprint (world meters), not just the table origin.
- Add a breathing floor indicator around the meeting table to guide where “inside the zone” is.

## Deliverables

- Code:
  - `vr_offices/npc/Npc.gd` suppress waiting timer when meeting-bound.
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingParticipationController.gd` uses table collision footprint distance.
  - `vr_offices/fx/MeetingZoneIndicator.tscn` + `vr_offices/fx/meeting_zone_indicator.gdshader` breathing soft ring.
  - `vr_offices/core/meeting_rooms/VrOfficesMeetingZoneIndicatorBinder.gd` wires the indicator under `Decor/MeetingZoneIndicator`.
- Tests:
  - Extend `tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd` to assert the indicator exists.
  - Extend `tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd` to cover the waiting-timer suppression.

## Verify

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd`
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_rooms_nodes.gd`
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices`

## Notes / Follow-ups

- The indicator is a rounded-rectangle SDF around the table footprint + radius; it’s intended to match the gameplay rule more closely than a simple circle.
- External IRC visibility (Python Tk observer) is still a separate slice: v94 only improves in-engine behavior and debugging UX.

