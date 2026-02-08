# v103 index

Goal: Ensure opening the NPC dialogue overlay does not synchronously render the full chat history in one frame (prevents 1–2s hitches tied to `events.jsonl` history size).

## Artifacts

- Plan: `docs/plan/v103-vr-offices-dialogue-history-incremental-render.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | History renders incrementally across frames | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_history_incremental_render.gd -TimeoutSec 240` | done |
| M2 | Suites stay green | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` | done |

## Evidence

- 2026-02-08:
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_history_incremental_render.gd -TimeoutSec 240` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0
