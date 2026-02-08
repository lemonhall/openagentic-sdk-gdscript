# v102 index

Goal: Stop `assistant.delta` spam from bloating `events.jsonl` and slowing down history loads; keep optional delta persistence in a separate debug log.

## Artifacts

- Plan: `docs/plan/v102-openagentic-stream-delta-log-hygiene.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | `assistant.delta` is streamed but not persisted | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/addons/openagentic/test_agent_runtime.gd -TimeoutSec 240` | done |
| M2 | UI history avoids parsing non-message events | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_chat_history_caps_ui_history.gd -TimeoutSec 240` | done |
| M3 | Suites stay green | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite openagentic -TimeoutSec 240` / `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` | done |

## Evidence

- 2026-02-08:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/addons/openagentic/test_agent_runtime.gd -TimeoutSec 240` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_chat_history_caps_ui_history.gd -TimeoutSec 240` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite openagentic -TimeoutSec 240` → EXIT=0
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0
