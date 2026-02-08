# v101 — VR Offices: NPC chat overlay history perf

## Problem

Opening the NPC chat overlay (`double click NPC`) became noticeably slow (1–2s hitch). The current talk-open path reads and parses the entire per-NPC `events.jsonl` and then renders all final messages into UI nodes. With meeting-room group chat + long sessions, the JSONL grows quickly (many `assistant.delta` events), making the “open overlay” action scale with log size.

## Scope

- Cap UI history to a fixed maximum number of items.
- Tail-read the JSONL so we only parse the newest portion of the file until the cap is satisfied.

## Non-scope

- Changing the session store format.
- “Load more history” pagination UI.

## Acceptance (Hard DoD)

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_chat_history_caps_ui_history.gd -TimeoutSec 240` → PASS
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0

## Update (2026-02-08)

This plan reduces the amount of history parsed/rendered, but it does not fully prevent “double-click hitch before overlay appears” if the open path still does main-thread `events.jsonl` disk I/O. The final fix for that is v107: background-thread tail-load of message history + log size.
