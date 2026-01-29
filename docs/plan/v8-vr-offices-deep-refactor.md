# v8 — VrOffices Deep Refactor

## Goal

Keep `vr_offices` maintainable by making `vr_offices/VrOffices.gd` a minimal scene orchestrator (~200 LOC) and moving remaining responsibilities into testable modules.

## Scope

In scope:

- Extract remaining logic from `vr_offices/VrOffices.gd` into modules.
- Keep public methods used by tests stable:
  - `add_npc()`, `remove_selected()`, `select_npc()`, `_enter_talk()`, `_exit_talk()`, `_unhandled_input()`
- Preserve OpenAgentic configuration behavior (save_id, default tools, hooks).
- Preserve autosave + persistence behavior.

Out of scope:

- Adding new gameplay features.
- Changing UI layout.
- Modifying `demo_rpg/`.

## Acceptance

- `wc -l vr_offices/VrOffices.gd` shows ≤ 220 and ideally ~200.
- The full Godot test suite passes:
  - `scripts\\run_godot_tests.ps1`

## Files

Create:

- `vr_offices/core/VrOfficesNpcManager.gd`
- `vr_offices/core/VrOfficesAgentBridge.gd`
- `vr_offices/core/VrOfficesSaveController.gd`

Modify:

- `vr_offices/VrOffices.gd`
- `.gitignore` (ignore local `tools/`)

## Design (module boundaries)

- **NpcManager**: selection, spawn/remove, culture+names, find-by-id, load NPCs from saved state.
- **AgentBridge**: OpenAgentic autoload configuration and turn hooks (animation triggers).
- **SaveController**: glue between WorldState IO and NpcManager load/save.
- **VrOffices.gd**: scene wiring only; delegates behavior to controllers.

## Risks

- Godot 4.6 strict mode: avoid inferred types from `null`/Variant; keep explicit typing in new modules.
- Tests rely on method names on `VrOffices.gd`; keep wrappers stable.

