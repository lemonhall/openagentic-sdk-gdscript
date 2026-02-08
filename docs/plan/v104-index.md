# v104 index

Goal: Opening NPC dialogue overlay does not synchronously read/parse `events.jsonl` in one frame; history loads incrementally without blocking input.

## Artifacts

- Plan: `docs/plan/v104-vr-offices-dialogue-history-incremental-load.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Incremental load of `events.jsonl` history | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_history_incremental_load.gd -TimeoutSec 240` | done |
| M2 | Suites stay green | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` | done |

## Evidence

- 2026-02-08:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_history_incremental_load.gd -TimeoutSec 240` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0
