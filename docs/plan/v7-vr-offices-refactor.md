# v7 — VrOffices Refactor

## Goal

Refactor `vr_offices/VrOffices.gd` (currently ~900 LOC) into smaller modules without changing observable behavior.

## Scope

### In scope

- Extract **data/constants** (models, culture name tables, system prompt) into a dedicated module.
- Extract helper logic for:
  - persistence (world state load/save)
  - input routing (selection, RMB floor command, dialogue gating)
  - chat history translation (session store → UI history)
  - BGM configuration helper(s)
- Keep `VrOffices.gd` as the orchestration layer and preserve existing public methods:
  - `add_npc()`
  - `remove_selected()`
  - `select_npc(npc)`
  - `set_culture(code)`
  - `autosave()`

### Out of scope

- New gameplay features
- New tools / agent runtime changes
- UI redesign

## Acceptance

- `vr_offices/VrOffices.gd` is reduced to **≤ 450 lines** (`wc -l`).
- All tests pass:
  - `scripts/run_godot_tests.ps1`
  - WSL/Linux workflow from `AGENTS.md` (optional but recommended)
- Manual smoke: open `VrOffices.tscn`, add NPC, talk (`E`), RMB move command works.

## Result

- Extracted modules live under `vr_offices/core/`:
  - `VrOfficesData.gd` (constants + culture tables)
  - `VrOfficesNpcProfiles.gd` (unique model reservation + naming)
  - `VrOfficesChatHistory.gd` (session store → UI history)
  - `VrOfficesWorldState.gd` (load/save `vr_offices/state.json`)
  - `VrOfficesDialogueController.gd` (dialogue lifecycle + camera focus)
  - `VrOfficesInputController.gd` (input routing: select/talk/move)
  - `VrOfficesMoveController.gd` (floor raycast + move indicator)
  - `VrOfficesBgm.gd` (BGM loop setup)

## Files

Expected touched:

- `vr_offices/VrOffices.gd`
- New: `vr_offices/core/*.gd` and/or `vr_offices/data/*.gd`
- `docs/plan/v7-index.md`
- `docs/plan/v7-vr-offices-refactor.md`

## Steps (Tashan loop)

1) **Red (guard rails):** run current suite to ensure baseline is green.
2) **Green:** move one responsibility at a time into helper modules, keeping behavior unchanged.
3) **Refactor:** simplify remaining `VrOffices.gd` and remove duplicated helper functions.
4) **Verify:** run the full suite again and confirm `VrOffices.gd` LOC target.

## Risks

- Godot 4.6 strict typing: any new typed variables initialized with `null` will fail parsing.
  - Mitigation: explicitly type nullable vars (`var x: Node = null`) and avoid inferred typing.
- Refactoring input/dialogue can break subtle interaction ordering.
  - Mitigation: keep event routing in `VrOffices.gd` unless tests cover it; move only pure helpers first.
