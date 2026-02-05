# VR Offices: Skill Library Thumbnails via Gemini Image Generation PRD

## Vision

When a Skill is installed into the shared Skill Library, the game automatically generates a small, kid-friendly cartoon thumbnail image for that skill. This thumbnail is stored with the library copy of the skill and reused in per-NPC skill management UI, avoiding redundant copies.

## Terminology

- **Shared Skill Library root**: `user://openagentic/saves/<save_id>/shared/skill_library/`
- **Installed skill dir**: `.../shared/skill_library/<skill_name>/`
- **Thumbnail path (MVP)**: `.../shared/skill_library/<skill_name>/thumbnail.png`
- **Gemini proxy base URL**: `https://www.right.codes/gemini` (or a local proxy URL; configurable)
- **Local dev proxy (recommended)**: `http://127.0.0.1:8787/gemini` (injects API key; forwards to right.codes)

## Requirements

### REQ-001 — Auto-generate thumbnail after library install

After a skill pack is installed successfully into the shared library:

- For each newly installed skill `<skill_name>`, generate a thumbnail and write it to:
  - `user://openagentic/saves/<save_id>/shared/skill_library/<skill_name>/thumbnail.png`
- Do not block the UI; run as a background job.
- If `thumbnail.png` already exists, skip generation unless explicitly forced.

### REQ-002 — Use Gemini image model through proxy endpoint

Generate thumbnails by calling the Gemini API through the proxy endpoint:

- Model name: `gemini-3-pro-image-preview`
- Endpoint shape (proxy): `.../v1beta/models/gemini-3-pro-image-preview:generateContent`
- Use the smallest image size available (thumbnail usage).
- Prompt style:
  - kid-friendly cartoon / toy-like, consistent with game’s vibe
  - no text, no logos, no watermarks
  - simple background, high readability at small size

Auth and proxying must be configurable (no secrets in repo).
In local dev, the proxy should inject the key so Godot does not need to send `x-goog-api-key`.

### REQ-003 — Online E2E connectivity test (manual review gate)

Add a headless online test that:

- is skipped unless `--oa-online-tests` is provided
- calls the configured Gemini proxy endpoint
- extracts the first image from the response
- writes a PNG to a caller-specified output path (default under `/tmp`)

This test is used to generate a sample thumbnail image for manual review before integrating into production code.

### REQ-004 — Library thumbnail reuse in NPC personal skills UI

In NPC personal skills management UI, the skill card thumbnail should be loaded from the shared library thumbnail when available:

- If skill `<skill_name>` has `thumbnail.png` in shared library, show it.
- If missing, show the placeholder.

This reuse avoids copying thumbnails into NPC workspaces.

## Non-Goals (MVP)

- Perfect art direction matching (prompt tuning can iterate later).
- Skill-tree UI or advanced skill categorization.
- Generating thumbnails inside NPC workspaces.
- Any changes under `demo_rpg/`.

## Open Questions

1) Proxy/auth: does the proxy inject an API key, or should the game provide `x-goog-api-key` from environment/config?
2) Preferred aspect ratio: `1:1` (icon) vs `16:9` (card) for thumbnails.
