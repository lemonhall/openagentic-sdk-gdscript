# v102 — OpenAgentic: stream delta log hygiene + perf

## Problem

The runtime persisted every streamed `text_delta` as an `assistant.delta` event into the canonical per-NPC `events.jsonl`. This creates extremely high-volume logs (often single-character deltas), which:

- bloats disk usage,
- slows down any feature that reads/parses `events.jsonl` (UI history, replay context, etc.),
- provides little value for normal operation (final `assistant.message` already contains the full output).

## Scope

- Stream `assistant.delta` events to the caller/UI, but **do not persist** them into `events.jsonl` by default.
- Add optional persistence of deltas into a separate debug file `deltas.jsonl` (opt-in via project setting).
- When reading histories, skip parsing delta lines for backward-compat logs.

## Acceptance (Hard DoD)

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/addons/openagentic/test_agent_runtime.gd -TimeoutSec 240` → PASS
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_chat_history_caps_ui_history.gd -TimeoutSec 240` → PASS
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite openagentic -TimeoutSec 240` → EXIT=0
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0

