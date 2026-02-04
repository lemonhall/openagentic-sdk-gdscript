# v55: Media tools read per-save config

## Problem

VR Offices UI can download/render media using per-save Settings → Media config, but OpenAgentic media tools (`MediaFetch`/`MediaUpload`) only read configuration from environment variables (or ctx). This makes the agent side report `MissingMediaConfig` even when the game is configured.

## Change

- Teach `MediaFetch`/`MediaUpload` config resolution to fall back to reading:
  - `user://openagentic/saves/<save_id>/vr_offices/media_config.json`
  when base URL / token are not available via ctx/env.

## Tests / Evidence

- Red → Green: new regression test fails before fix and passes after:
  - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_tool_media_config_from_save_file.gd` (PASS)

