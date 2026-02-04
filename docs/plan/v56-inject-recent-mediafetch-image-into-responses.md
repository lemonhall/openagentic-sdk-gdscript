# v56: Inject recent MediaFetch image into Responses input

## Problem

Even when the game has downloaded/rendered an image, the LLM often cannot “see” it because the agent runtime currently sends only plain text messages to the OpenAI Responses API. This leads the model to attempt incorrect workarounds (e.g. `Read` on PNG bytes, `RemoteBash` + PIL) and sometimes produces `no_output`.

## Decision (Option A)

After a successful `MediaFetch`, inject the fetched image into the *next* user message as a Responses `input_image` part:

- Detect the most recent successful `MediaFetch` that occurred between the previous and current `user.message`.
- Inline the fetched file from the NPC workspace as `data:<mime>;base64,...`.
- Convert the last user message into `content: [ {type: input_text}, {type: input_image} ]`.

This is intentionally minimal and avoids broad “always attach images” behavior.

## Tests / Evidence

- New regression test:
  - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_agent_runtime_injects_recent_media_image.gd` (PASS)
- Hook robustness test (BeforeTurn override still works after content becomes parts):
  - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_agent_runtime_override_user_text_with_injected_image.gd` (PASS)
