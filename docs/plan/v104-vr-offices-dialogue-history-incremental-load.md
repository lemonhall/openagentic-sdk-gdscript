# v104 — VR Offices: Dialogue overlay incremental history load from events.jsonl

## Problem

Even with incremental UI rendering, opening the NPC dialogue overlay can still hitch if we **synchronously read/parse** the per-NPC `events.jsonl` on the main thread. Users observed a 1–2s stall even when `events.jsonl` is ~88KB.

## Scope

- Move `events.jsonl` **history load (read + parse + filter)** to a **frame-sliced incremental loader**.
- Keep the same effective history semantics: last `N` `user.message` / `assistant.message` items, ordered oldest → newest.
- Preserve existing fallback for legacy manager events path (`<workspace_id>_manager`).

## Non-scope

- Background threads / worker pools (keep single-threaded; avoid thread-safety footguns).
- Changing the canonical persisted log format.

## Acceptance (Hard DoD)

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_history_incremental_load.gd -TimeoutSec 240` → PASS
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0

