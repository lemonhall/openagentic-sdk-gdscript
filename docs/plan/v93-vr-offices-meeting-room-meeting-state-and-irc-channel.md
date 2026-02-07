# v93 — VR Offices: Meeting Room meeting state + IRC channel group chat

PRD: `docs/prd/2026-02-07-vr-offices-meeting-room-npc-meeting-state-and-irc-channel.md`

## Scope

Deliver the first functional loop for Meeting Rooms:

- NPC commanded near a meeting table (≤ 2m) enters a **meeting state** and stays in-place (no wandering).
- Each Meeting Room has a stable derived **channel name** (IRC-style), respecting the server’s `NICKLEN=9` constraint for derived participant nicks.
- The mic overlay acts as the **human group-chat entry**: sending a message broadcasts to meeting participants.
- Mentions force reply; otherwise NPCs may or may not reply (deterministic policy, at least one reply).

## Non-scope (explicit)

- Real external IRC networking per NPC (join/part on a live IRC server).
- Rich roster UI / click-to-mention.
- Perfect natural-language mention detection.
- Parallel/concurrent streaming replies (sequential is OK for v93).

## Plan (塔山开发循环 per slice)

### Slice 1 — Channel naming + mentions parsing (Red → Green → Refactor)

- Add a deterministic `derive_channel_for_meeting_room(save_id, meeting_room_id, channellen)` helper.
- Add a mentions parser that supports:
  - `@DisplayNameToken` / `@npc_id`
  - `DisplayName:` / `npc_id:` at the start of the line (supports spaces in DisplayName)
- Tests:
  - Channel name: stable, safe charset, length ≤ configured `channellen` (default 50).
  - Mentions: sample messages yield expected mentioned npc ids.

Verify:

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_channel_names_and_mentions.gd`

### Slice 2 — NPC enter/exit meeting state based on move-to target (Red → Green → Refactor)

- On NPC move-to completion:
  - if within 2.0m of a meeting table anchor → join meeting room + disable wandering (“stay”)
  - if leaving beyond 2.2m (hysteresis) → exit meeting state + restore wandering rules
- Handle meeting room deletion cleanup (no dangling meeting bindings).
- Tests:
  - Command NPC to a point near the meeting table → enters meeting state.
  - Command NPC to a far point → exits meeting state.

Verify:

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_npc_meeting_state_enter_exit.gd`

### Slice 3 — Mic overlay group chat broadcast (Red → Green → Refactor)

- Replace “meetingroom_<id> runs OpenAgentic” with:
  - human message → broadcast to participants
  - participants respond (mentions force, else deterministic selection; sequential streaming)
- Keep overlay independent and no-skills UI.
- Tests:
  - With 2 NPCs in meeting state, send a message → at least one NPC reply appears.
  - With a mention targeting NPC A, ensure NPC A replies.

Verify:

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_meeting_room_group_chat_broadcast.gd`

### Slice 4 — Regression suite

Verify:

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices`

## Risks & mitigations

- **Nick length constraint (NICKLEN=9)**: keep derived IRC nick ≤ 9 chars (reuse `VrOfficesIrcNames.derive_nick(..., nicklen)` with nicklen from config).
- **UI limitations**: `DialogueOverlay` is single-assistant-stream; v93 runs NPC replies sequentially and prefixes replies with `DisplayName:` to preserve readability.
- **Headless tests**: avoid external IRC dependencies; use FakeOpenAgentic in tests.

## DoD

- All v93 tests pass + full `-Suite vr_offices`.
- Meeting features remain isolated under `vr_offices/core/meeting_rooms/` (no cross-talk with desks/workspaces).
- No files in `vr_offices/core/**/*.gd` exceed the layout guard limits.

