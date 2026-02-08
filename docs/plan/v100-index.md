# v100 index

Goal: Fix Meeting Room invitation movement so RMB inside-room behaves like a normal move target (not a fixed point under the table), while still enforcing invite-only meeting join/leave semantics.

## Artifacts

- PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md` (REQ-001 / REQ-004)
- Plan: `docs/plan/v100-vr-offices-meeting-room-invite-target-and-control.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | RMB invite uses clicked floor target (clamped) | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_room_invite_uses_clicked_target.gd -TimeoutSec 240` | done |
| M2 | Invited/pending NPC stays controllable (RMB inside room no longer re-invites) | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_room_invite_uses_clicked_target.gd -TimeoutSec 240` | done |
| M3 | Suite stays green | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` | done |

## Traceability

| Req ID | Plan | Tests / Verify | Evidence |
|---|---|---|---|
| REQ-001 | v100 | `tests/projects/vr_offices/test_vr_offices_meeting_room_invite_uses_clicked_target.gd` | 2026-02-08 PASS |
| REQ-004 | v100 | `tests/projects/vr_offices/test_e2e_meeting_room_irc_join_localhost.gd` | (manual/localhost) |

## Evidence

- 2026-02-08:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_room_invite_uses_clicked_target.gd -TimeoutSec 240` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0
