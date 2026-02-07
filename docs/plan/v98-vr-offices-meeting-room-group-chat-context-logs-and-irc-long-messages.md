# v98 — VR Offices: Meeting Room group chat context + logs + IRC long messages

PRD adjacency: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md` (REQ-008 / REQ-009)

## Problem

Manual play feels like “host message is fanned out per NPC” instead of a shared meeting:

- NPCs lack explicit meeting context (who/where/what) per turn.
- Long messages over IRC can be silently truncated by the wire limit.
- No persistent meeting-room event log for debugging (“谁 join/part 了？谁说了啥？”).

## Scope

- Inject meeting context + recent public transcript into each NPC turn (prompt framing).
- Split long IRC PRIVMSG into multiple lines (prevents truncation).
- Write a per-meeting-room JSONL event log under the save directory.
- Add an online E2E test against localhost IRC (`127.0.0.1:6667`) proving:
  - derived channel exists and all participants JOIN
  - host + a mentioned NPC send observable PRIVMSG
  - long NPC reply survives transport (not truncated)
  - meeting-room event log exists and contains join+msg events

## Non-scope (explicit)

- Treat IRC as the *only* source-of-truth for in-engine routing (incoming IRC driving NPC turns).
- UI-side reassembly of long multi-line IRC messages.

## Acceptance (Hard DoD)

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_group_chat_localhost.gd -TimeoutSec 240 -ExtraArgs --oa-online-tests` passes against a real IRC server on `127.0.0.1:6667`.
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` exits 0.

## Evidence

- 2026-02-07:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_e2e_meeting_room_irc_group_chat_localhost.gd -TimeoutSec 240 -ExtraArgs --oa-online-tests` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices` → EXIT=0

