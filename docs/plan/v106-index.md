# v106 index

Goal: Opening the NPC dialogue overlay does not synchronously access `events.jsonl` in the same frame; disk I/O happens after first draw.

## Artifacts

- Plan: `docs/plan/v106-vr-offices-dialogue-open-defer-io.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Size label refresh deferred | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd -TimeoutSec 240` | todo |
| M2 | Suites stay green | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` | todo |

## Evidence

- 2026-02-08:
  - (pending)

