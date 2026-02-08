# v101 index

Goal: Fix the 1–2s hitch when opening an NPC chat overlay by bounding the amount of per-NPC session history parsed and rendered.

Status: v101 bounds parsing/rendering, but the “overlay appears late” hitch was ultimately caused by main-thread `events.jsonl` disk I/O; see v107 for the final fix.

## Artifacts

- Plan: `docs/plan/v101-vr-offices-npc-chat-overlay-history-perf.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | UI history is capped + tail-read | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_chat_history_caps_ui_history.gd -TimeoutSec 240` | done |
| M2 | VR Offices suite stays green | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` | done |

## Evidence

- 2026-02-08:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_chat_history_caps_ui_history.gd -TimeoutSec 240` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0
