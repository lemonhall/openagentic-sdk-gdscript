# v76 index

Goal: fix NPC skills summary generation (`NoDoneEvent`) by updating SSE parsing to treat Responses API terminal events (e.g. `response.completed`) as `done`.

## Artifacts

- Plan: `docs/plan/v76-fix-sse-done-event-response-completed.md`

## Evidence

- 2026-02-05
  - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_sse_parser.gd` PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` PASS
