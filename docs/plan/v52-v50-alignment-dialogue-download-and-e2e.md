<!--
  v52 — v50 alignment fixes plan
-->

# v52 — v50 alignment fixes (Dialogue download + E2E + service smoke)

## Goal

Make the implementation match the v50 plan/DoD:

- `DialogueOverlay` must auto-download images to per-save cache when missing/corrupt.
- Verification must include a real media_service behavior smoke test.
- E2E must cover the player-side cache download path (remote → player).

## PRD Trace

- REQ-004, REQ-005, REQ-006, REQ-009

PRD: `docs/prd/2026-02-04-vr-offices-multimedia-messages.md`

## Scope

In scope:

- Add a reusable “download-to-cache” helper with injectable transport for tests.
- Update `DialogueOverlay` image rendering path to:
  - load from cache if valid;
  - otherwise download (`GET /media/<id>`) using env-configured bearer token;
  - verify `bytes/sha256`, store cache, then render;
  - show deterministic error label on failure.
- Add a real Node smoke test for `media_service/server.mjs` covering:
  - unauth download is 401;
  - wrong token is 403;
  - wrong magic number is 415;
  - valid PNG upload returns 200 and can be downloaded with correct token.
- Extend `tests/e2e/test_multimedia_flow.gd` to also instantiate `DialogueOverlay` and validate player cache + render.

Out of scope:

- Audio/video playback controls (still planned later).
- Cross-platform shell-open flows.

## Acceptance (DoD)

1) When a valid `OAMEDIA1` image message is received and cache is missing, `DialogueOverlay` downloads and renders the image.
2) When cached bytes exist but `sha256/bytes` mismatch, it re-downloads (or fails with a visible deterministic error).
3) Failures are visible: missing env, HTTP error, sha mismatch, etc. do not crash.
4) Media service smoke test asserts auth + sniff behavior against the real server.
5) E2E covers both:
   - tool-side upload → IRC → reassemble → fetch to workspace
   - remote → player `DialogueOverlay` downloads to per-save cache and renders

## Files

Modify:

- `vr_offices/ui/DialogueOverlay.gd`
- `tests/e2e/test_multimedia_flow.gd`

Add:

- `vr_offices/core/media/VrOfficesMediaDownloader.gd`
- `tests/projects/vr_offices/test_vr_offices_dialogue_media_image_download.gd`
- `media_service/smoke_test.mjs`

## Steps (塔山开发循环)

### Slice A — Dialogue auto-download (RED→GREEN)

1) **Red**: add `tests/projects/vr_offices/test_vr_offices_dialogue_media_image_download.gd`
2) **Green**: implement downloader + wire into `DialogueOverlay`
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_media_image_download.gd
```

### Slice B — Media service smoke (RED→GREEN)

1) **Green**: add `media_service/smoke_test.mjs`
2) **Verify**:

```bash
node media_service/smoke_test.mjs
```

### Slice C — Extend E2E to player cache (RED→GREEN)

1) **Red/Green**: extend `tests/e2e/test_multimedia_flow.gd` with a player-side phase
2) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/e2e/test_multimedia_flow.gd
```

