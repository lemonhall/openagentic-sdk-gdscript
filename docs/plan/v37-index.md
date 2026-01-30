<!--
  v37 — VR Offices: core modularization (anti-god-files)
-->

# v37 — VR Offices: Core Modularization (No God Files)

## Vision (this version)

- `vr_offices/core/` is organized into module subfolders (no flat “core with dozens of files”).
- No `.gd` file under `vr_offices/core/**` exceeds 200 lines.
- Behavior stays stable (tests pass; no gameplay/UI changes).

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Guardrails | Add a test that enforces core layout + max file lines | `tests/test_vr_offices_core_layout_guard.gd` | todo |
| M2 | Desks module | Split/refactor desks-related core scripts under `vr_offices/core/desks/` | `tests/test_vr_offices_workspace_desks_model.gd` | todo |
| M3 | Workspaces module | Split/refactor workspaces-related core scripts under `vr_offices/core/workspaces/` | `tests/test_vr_offices_workspaces_model.gd` | todo |
| M4 | NPC/Input module | Split/refactor input + npc scripts under `vr_offices/core/input/` and `vr_offices/core/npcs/` | `tests/test_vr_offices_smoke.gd` | todo |

## Plan Index

- `docs/plan/v37-vr-offices-core-refactor.md`

