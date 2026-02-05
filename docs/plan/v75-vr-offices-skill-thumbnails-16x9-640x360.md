# v75 VR Offices: Skill thumbnails — 16:9 640×360

## Goal

Store shared skill library thumbnails as 16:9 PNG card covers at 640×360 (`thumbnail.png`) so the NPC skill card UI does not rely on cropping square icons.

## PRD Trace

- `REQ-001` Auto-generate thumbnail after library install
- `REQ-002` Use Gemini image model through proxy endpoint
- `REQ-005` Always produce PNG thumbnail (convert/resize)

## Acceptance (DoD)

1) Thumbnail generation calls Gemini with `aspectRatio: "16:9"` and stores `thumbnail.png` as a PNG file resized to **640×360**.
2) If an existing `thumbnail.png` is not 640×360, generation re-runs to replace it (best-effort migration).
3) Offline tests assert the output PNG dimensions are 640×360.
4) `scripts/run_godot_tests.sh --suite vr_offices` is green.

## Files

Modify:

- `docs/prd/2026-02-05-vr-offices-skill-library-thumbnails-gemini.md`
- `vr_offices/core/skill_library/thumbnails/VrOfficesGeminiImageClient.gd`
- `vr_offices/core/skill_library/thumbnails/VrOfficesSkillThumbnailGenerator.gd`
- `tests/projects/vr_offices/test_skill_library_thumbnails.gd`
- `tests/projects/vr_offices/test_gemini_skill_thumbnail_online.gd`

## Verify

- `scripts/run_godot_tests.sh --suite vr_offices`
