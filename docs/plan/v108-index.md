# v108 index

Goal: Backport the “dialogue overlay must not do main-thread `events.jsonl` I/O on open” constraint into PRD-level requirements, so future features cannot regress into talk-open hitches.

## Artifacts

- PRD: `docs/prd/2026-02-08-vr-offices-dialogue-overlay-log-io-performance.md`
- Plan: `docs/plan/v108-vr-offices-dialogue-overlay-perf-prd-backport.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Add PRD for log I/O perf + cross-link | `rg -n "No Main-thread Log I/O" docs/prd/2026-02-08-vr-offices-dialogue-overlay-log-io-performance.md; rg -n "2026-02-08-vr-offices-dialogue-overlay-log-io-performance" docs/prd/2026-02-04-vr-offices-multimedia-messages.md` | done |
| M2 | Guard open-path behavior stays enforced | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd -TimeoutSec 240` | done |
| M3 | Guard async history load stays enforced | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_per_npc_history.gd -TimeoutSec 240` | done |

## Evidence

- 2026-02-08:
  - `rg -n "No Main-thread Log I/O" docs/prd/2026-02-08-vr-offices-dialogue-overlay-log-io-performance.md` → match
  - `rg -n "2026-02-08-vr-offices-dialogue-overlay-log-io-performance" docs/prd/2026-02-04-vr-offices-multimedia-messages.md` → match
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd -TimeoutSec 240` → PASS
  - `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_per_npc_history.gd -TimeoutSec 240` → PASS

