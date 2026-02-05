# v76 Fix: SSE `done` event for `response.completed`

## Goal

Fix NPC skills summary generation in VR Offices that currently shows `(summary error: NoDoneEvent)` by ensuring the OpenAI Responses SSE parser emits a `done` event when the stream ends with terminal events like `response.completed` (instead of `[DONE]`).

## Scope

- Extend `OASseParser` to treat `response.completed` as a terminal event and emit `{type:"done"}`.
- Add a regression test that reproduces the missing `done` case with an SSE payload containing `response.completed` but no `[DONE]`.

## Acceptance (DoD)

1) `tests/addons/openagentic/test_sse_parser.gd` asserts `done` is emitted for both:
   - legacy `[DONE]` sentinel
   - terminal JSON event `{"type":"response.completed"}` without `[DONE]`
2) `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_sse_parser.gd` is green.
3) `scripts/run_godot_tests.sh --suite vr_offices` is green.

## Files

Modify:

- `addons/openagentic/providers/OASseParser.gd`
- `tests/addons/openagentic/test_sse_parser.gd`

## Verify

- `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_sse_parser.gd`
- `scripts/run_godot_tests.sh --suite vr_offices`
