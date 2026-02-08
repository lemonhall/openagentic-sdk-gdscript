# v103 — VR Offices: Dialogue overlay history incremental render

## Problem

Opening the NPC dialogue overlay (`double click NPC`) can still hitch for ~1–2 seconds when the per-NPC `events.jsonl` contains enough chat history to rebuild many UI bubbles. Even when history parsing is bounded, **synchronously instantiating and laying out** a large number of message rows inside `DialogueOverlay.set_history()` blocks the main thread and delays the overlay appearing.

## Scope

- Render persisted history in **small batches across frames** instead of all-at-once.
- Keep behavior identical once rendering completes (same message ordering and bubble contents).

## Non-scope

- Changing the persisted session store format.
- “Load more history” pagination UI.
- Background threads / worker pools (stay single-threaded, frame-sliced).

## Acceptance (Hard DoD)

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_history_incremental_render.gd -TimeoutSec 240` → PASS
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0

