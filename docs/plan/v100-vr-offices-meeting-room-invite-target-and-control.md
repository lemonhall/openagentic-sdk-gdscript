# v100 — VR Offices: Meeting Room invite target + controllability fix

PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md` (REQ-001 / REQ-004)

## Problem

In-game, RMB-in-room “invite” currently overrides the move destination with a deterministic point around the table (and can end up under/inside the table), causing NPCs to get stuck and never reach `move_target_reached`. While pending, further RMB commands feel ignored because clicks inside the room keep re-inviting (resetting the same broken target). As a result, NPCs never JOIN the real IRC channel.

## Scope

- Invitation target:
  - RMB inside a meeting room uses the **clicked floor point** (clamped to the room rect with padding) as the move target, not a fixed “table ring” point.
  - If the clicked point is too close to the table center, nudge to a safe radius before clamping.
- Controllability:
  - If an NPC is already **meeting-bound or pending** for that room, RMB inside the room should behave like a normal move (no re-invite override).
  - Pending invites only bind + JOIN when the reached target is **inside the room rect**; reaching a target outside cancels the pending invite.

## Non-scope

- Navmesh tuning / collision authoring of the table assets.
- Seating assignments.

## Acceptance (Hard DoD)

Offline (headless) must PASS:

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_room_invite_uses_clicked_target.gd -TimeoutSec 240`
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240`

Online (localhost IRC) should still PASS (manual/CI optional):

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd -TimeoutSec 240 -ExtraArgs --oa-online-tests`

## Steps (塔山开发循环)

1) **Red:** add a regression test proving RMB-in-room uses the clicked target and that pending NPCs stay controllable.
2) **Green:** implement target selection + transformer behavior changes until the test passes.
3) **Refactor:** keep changes minimal; run `-Suite vr_offices` as evidence.

