# v72 VR Offices: Skill library thumbnails (Gemini) — online E2E gate

## Goal

Add an online E2E test that can call the Gemini proxy endpoint and write a sample PNG thumbnail to disk for manual review. This is a gate before implementing production provider + library integration.

## PRD Trace

- `docs/prd/2026-02-05-vr-offices-skill-library-thumbnails-gemini.md`
  - REQ-003

## Scope

### In scope (v72)

- New online test:
  - Calls `.../v1beta/models/gemini-3-pro-image-preview:generateContent`
  - Sends a skill-thumbnail prompt (kid-friendly cartoon style, no text)
  - Extracts image bytes from response and writes `thumbnail.png` to an output path.
- No production integration yet.

### Out of scope (v72)

- Provider/client implementation used by runtime UI.
- Auto generation after install.
- Showing thumbnails in library or NPC UI.

## Acceptance (DoD)

1) `tests/projects/vr_offices/test_gemini_skill_thumbnail_online.gd` exists and:
   - passes with `--oa-online-tests` when configured with base url + auth as needed
   - writes a PNG file to an output path (default `/tmp/oa_gemini_skill_thumb.png`)
   - validates the output looks like a PNG (magic bytes) and is non-empty
2) Test is skipped (PASS) when `--oa-online-tests` is not provided.

## Steps (TDD)

### RED

- Add the online test file and run it without `--oa-online-tests` (should SKIP and PASS).
- Run with `--oa-online-tests` expecting it to fail until endpoint/auth is correct (or fail due to missing key), but the code path is exercised.

### GREEN

- Implement HTTP request with timeout + optional proxy args.
- Implement robust response JSON parsing to find the first image base64 field.
- Write bytes to output path and validate PNG signature.

### VERIFY

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_gemini_skill_thumbnail_online.gd`
- `OPENAGENTIC_GEMINI_API_KEY=... scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_gemini_skill_thumbnail_online.gd --extra-args --oa-online-tests --oa-gemini-base-url=... --oa-gemini-out=...`

## Risks / Notes

- Endpoint schema may change; keep parsing resilient and emit readable errors with HTTP status + truncated body.
- Never commit keys; accept via args/env only.
