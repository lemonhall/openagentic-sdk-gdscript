# v6 — Future Hook Points (not implemented yet)

This document captures the next hook points we may add to match the Python SDK’s “lifecycle hooks” idea.

## Candidate hook points

- `BeforeTurn` / `AfterTurn` (v6 scope)
- `BeforeModelCall` / `AfterModelCall`
  - Inject world state / global memory summary.
  - Apply consistent system instructions without duplicating logic in every game scene.
  - Centralize retry/backoff and error handling.
- `SessionStart` / `SessionEnd`
  - Initialize or migrate session state.
  - Force-save office state on exit.
- `BeforeReplay` / `AfterReplay`
  - Repair legacy events or fill missing tool outputs.
  - Apply schema migrations.
- `BeforeCompaction` / `AfterCompaction`
  - Keep context small by auto-summarizing long dialogue.
  - Maintain “world summary” and “NPC summary” artifacts.
- `OnStop`
  - React to user stop/model stop: halt animations, cancel streaming UI, cleanup state.

## Why these matter (gameplay)

Turn hooks help “feel” immediately, but the model/session/compaction hooks are what enable:

- stable long-running NPC memory without context overflow
- consistent cross-NPC behavior policies
- richer animation/behavior integration (thinking, speaking, tool-usage VFX)

