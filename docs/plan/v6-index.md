# v6 Index — Turn Hooks (Gameplay/UI Integration)

## Vision (v6)

Extend the hooks system beyond tools so games can integrate agent runtime events into gameplay:

- drive **animations / VFX / UI states** around each dialogue turn
- keep the agent runtime extensible without forking core logic
- preserve a replayable audit trail via persisted `hook.event` entries

This v6 focuses on the simplest useful slice: **turn-level hooks**.

## Milestones (facts panel)

1. **Design:** document hook points and payload shapes. (done)
2. **Turn hooks:** implement `BeforeTurn` / `AfterTurn` hooks and expose on `OpenAgentic`. (done)
3. **Tests:** coverage for turn hooks + persistence to session events. (done)

## Plans (v6)

- `docs/plan/v6-hooks-turn.md` (B: `before_turn` / `after_turn`)
- `docs/plan/v6-hooks-future.md` (other hook points for later iterations)

## Definition of Done (DoD)

- Turn hooks can be registered from runtime via `OpenAgentic`.
- Hooks execute reliably (sync + async) and are persisted as `hook.event` entries.
- Headless tests cover the behavior and run with:
  - `scripts/run_godot_tests.ps1`
  - `scripts/run_godot_tests.sh`
