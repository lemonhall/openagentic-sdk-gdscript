# v107 index

Goal: NPC dialogue overlay opens immediately even when `events.jsonl` is large; history and size label are loaded via a background tail-scan job.

## Artifacts

- Plan: `docs/plan/v107-vr-offices-dialogue-history-threaded-tail-load.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Threaded tail-load history | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_history_incremental_load.gd -TimeoutSec 240` | done |
| M2 | Per-NPC history test updated | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_per_npc_history.gd -TimeoutSec 240` | done |
| M3 | Suites stay green | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` | done |

## Evidence

- 2026-02-08:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_history_incremental_load.gd -TimeoutSec 240` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_per_npc_history.gd -TimeoutSec 240` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0
