# v107 — VR Offices: Threaded tail-load for events.jsonl history

## Problem

Players report a 1–2s hitch on NPC double-click before the dialogue overlay becomes visible. They also report that clearing the per-NPC session logs makes the overlay open instantly, strongly implicating `events.jsonl` disk I/O / parsing as the blocker.

Even “deferred” work can still run before the next frame is rendered, so any main-thread file open/seek/parse can prevent the overlay from appearing.

## Scope

- Zero main-thread disk I/O on the talk-open frame.
- Load per-NPC history using a background thread and a **tail scan** that parses only `user.message` / `assistant.message` lines (bounded by `max_items`).
- Populate `events.jsonl=<size>` label from the background job (no synchronous file opens in `DialogueOverlay.open()`).
- Update tests that previously assumed synchronous history reconstruction.

## Non-scope

- Full pagination / “load older on scroll”.
- Background parsing of the entire log (we only need the tail to render the most recent context).

## Acceptance (Hard DoD)

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_history_incremental_load.gd -TimeoutSec 240` → PASS
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_per_npc_history.gd -TimeoutSec 240` → PASS
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0

