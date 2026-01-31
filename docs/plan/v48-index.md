<!--
  v48 — VR Offices: Dialogue overlay shows session log size + one-click clear
-->

# v48 — Dialogue: Session Log Size + One-Click Clear

## Vision (this version)

- Reduce long “mystery state” debugging sessions caused by persisted chat history:
  - In the NPC dialogue overlay header, show the current `events.jsonl` size.
  - Provide a one-click “clear” button to truncate the persisted per-NPC session log.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Dialogue overlay header | Shows `events.jsonl=<size>` and supports one-click clear (per NPC) | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd` | done |

## Plan Index

- `docs/plan/v48-dialogue-session-log-size-and-clear.md`

## Evidence

Green:

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd` (PASS)
- `scripts/run_godot_tests.sh --suite vr_offices` (PASS)
