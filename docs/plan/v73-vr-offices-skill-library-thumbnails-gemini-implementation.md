# v73 VR Offices: Skill library thumbnails (Gemini) — production implementation

## Goal

When a skill pack is installed into the shared skill library, automatically generate a kid-friendly cartoon thumbnail using Gemini (via local proxy) and store it as `thumbnail.png` in the installed skill directory. The NPC personal skill management UI reuses that thumbnail if present.

## PRD Trace

- `REQ-001` Auto-generate thumbnail after library install
- `REQ-002` Use Gemini image model through proxy endpoint
- `REQ-004` Library thumbnail reuse in NPC personal skills UI
- `REQ-005` Always produce PNG thumbnail (convert/resize)

## Scope

- Add a small thumbnail generation service for the shared skill library.
- Add a Gemini image client that extracts inline image data and converts to PNG.
- Hook the library install flow to enqueue thumbnail generation (non-blocking).
- Render skill thumbnails in NPC skill cards by loading from shared library.

## Non-Goals

- Art direction perfection (prompt tuning will iterate).
- Generating thumbnails for already-installed skills (can be added later).
- Any changes under `demo_rpg/`.

## Acceptance (DoD)

1) After a successful install in `VendingMachineOverlay`, the code enqueues thumbnail generation for each newly installed skill without blocking the UI.
2) Thumbnail generation:
   - Calls Gemini `gemini-3-pro-image-preview` through `OPENAGENTIC_GEMINI_BASE_URL` (default: `http://127.0.0.1:8787/gemini`).
   - Extracts the first inline image from the JSON response.
   - Writes `user://openagentic/saves/<save_id>/shared/skill_library/<skill_name>/thumbnail.png` as a PNG file.
   - If the returned image is JPEG (or any non-PNG), converts to PNG first.
   - Resizes to 256×256 before writing.
   - Retries up to 3 times on failure.
3) NPC skills overlay loads and displays `thumbnail.png` from the shared library when present; otherwise shows the placeholder.
4) Tests:
   - Offline tests validate inline image extraction, JPEG→PNG conversion, and correct output path + skip-on-exists behavior.
   - `scripts/run_godot_tests.sh --suite vr_offices` is green.

## Files

Create:

- `vr_offices/core/skill_library/thumbnails/VrOfficesGeminiImageClient.gd`
- `vr_offices/core/skill_library/thumbnails/VrOfficesSkillThumbnailGenerator.gd`
- `vr_offices/core/skill_library/thumbnails/VrOfficesSkillLibraryThumbnailService.gd`
- `tests/projects/vr_offices/test_skill_library_thumbnails.gd`

Modify:

- `vr_offices/ui/VendingMachineOverlay.gd`
- `vr_offices/ui/VrOfficesNpcSkillsOverlay.gd`
- `vr_offices/core/skill_library/VrOfficesSharedSkillLibraryPaths.gd`
- `tests/projects/vr_offices/test_gemini_skill_thumbnail_online.gd` (always save PNG)

## Steps (TDD)

1) RED: add offline tests for extraction + conversion + write path.
2) GREEN: implement minimal client conversion + generator to satisfy tests.
3) GREEN: add service queue + install hook, and update NPC UI rendering.
4) REFACTOR: keep `vr_offices/core/**/*.gd` files ≤200 LOC and names coherent.
5) VERIFY: `scripts/run_godot_tests.sh --suite vr_offices`

## Risks

- Gemini may return JPEG by default; conversion must be robust.
- Network flakiness: keep online test opt-in (`--oa-online-tests`), rely on offline unit tests for CI.
