# v105 index

Goal: NPC double-click talk-open does not synchronously load 3D preview models; overlay appears immediately and preview loads asynchronously.

## Artifacts

- Plan: `docs/plan/v105-vr-offices-manager-preview-async-load.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Preview loads deferred/threaded | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_manager_dialogue_preview_async_load.gd -TimeoutSec 240` | todo |
| M2 | Suites stay green | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` | todo |

## Evidence

- 2026-02-08:
  - (pending)

