# v50 — Multimedia Messages (Dialogue + IRC) — Foundation Plan

## Goal

Deliver the first end-to-end slice of “multimedia messages” safely:

- Define a stable `OAMEDIA1` text protocol (works in Dialogue + IRC).
- Provide a separate (non-`proxy/`) media service skeleton with bearer auth + MIME allowlist.
- Implement **image attachments** (PNG/JPEG) in `DialogueOverlay` with local cache and integrity checks.

## PRD Trace

- REQ-001, REQ-002 (media ref format + validation)
- REQ-003, REQ-004 (media service + security)
- REQ-005, REQ-006 (Dialogue rendering + cache)
- REQ-007, REQ-008 (agent tools workflow)
- REQ-009 (IRC transport constraints)

PRD: `docs/prd/2026-02-04-vr-offices-multimedia-messages.md`

## Scope

In scope (v50):

- A strict parser/encoder for `OAMEDIA1` references.
- A **separate** media service directory (not `proxy/`) with:
  - bearer auth (upload + download)
  - MIME sniff + allowlist
  - size limits (explicit thresholds: image≤8MiB, audio≤20MiB, video≤64MiB)
- DialogueOverlay:
  - renders image attachments referenced via `OAMEDIA1`
  - downloads to per-save cache and verifies `sha256/bytes`
  - shows a clear placeholder on failure (and never crashes)
- IRC transport:
  - define one-line encoding rules + fragmentation strategy (design + tests)
  - implement minimal handling in desk IRC bridge to ignore/forward safely

Out of scope (v50):

- Audio playback UI (MP3/WAV)
- Video playback UI (MP4) beyond “safe download/open externally”
- Full UX polish (file pickers, drag-and-drop, progress UI)
- Making the LLM natively “see/hear” media (multimodal model input); planned later

## Acceptance (DoD)

Each item must be pass/fail verifiable:

1) `OAMEDIA1` parser rejects invalid payloads (missing fields, bad base64, wrong mime, oversized lengths).
2) Media service denies download without bearer auth (401/403) even if `id` is known.
3) Media service rejects uploads that fail magic-number MIME sniff or exceed size limits (image≤8MiB, audio≤20MiB, video≤64MiB).
4) DialogueOverlay displays images for valid refs and shows a deterministic “failed to load” placeholder for invalid/unavailable refs.
5) Cache integrity: corrupted cached bytes are detected and re-downloaded (or hard-fail with a visible error).
6) Agent tools (upload/fetch) accept only workspace-relative paths and never return host-absolute paths.
7) IRC transport: `OAMEDIA1` frames never conflict with `OA1 `; encoded payload fits message length constraints (or fragments with reassembly rules) and tests cover.

Anti-cheat clause:

- Adding “just a label that says image” does **not** count. Must actually download + validate + render (for images) with a regression test.

## Files

Modify (expected):

- `vr_offices/ui/DialogueOverlay.gd`
- `vr_offices/core/chat/VrOfficesChatHistory.gd`
- `vr_offices/furniture/DeskNpcDeskChannelBridge.gd`
- `addons/openagentic/tools/OAStandardTools.gd` (or a dedicated new tool file)
- `addons/openagentic/runtime/OAReplay.gd` (only if required for agent workflow)

Add (expected):

- `addons/openagentic/core/OAMediaRef.gd` (parser/encoder)
- `media_service/` (new top-level folder; separate from `proxy/`)
- Tests:
  - `tests/addons/openagentic/test_media_ref_parser.gd`
  - `tests/projects/vr_offices/test_vr_offices_dialogue_media_image.gd`
  - `tests/addons/openagentic/test_tool_media_upload_fetch.gd`
  - `tests/projects/vr_offices/test_irc_media_ref_transport.gd`

## Steps (塔山开发循环)

### Slice 1 — `OAMEDIA1` protocol + parser (REQ-001/002/009)

1) **Red**: add `tests/addons/openagentic/test_media_ref_parser.gd`:
   - valid `OAMEDIA1` decodes to expected fields
   - invalid cases: wrong prefix/version, bad base64url, missing `id/kind/mime`, wrong allowlist, negative/overflow sizes
2) **Green**: implement `addons/openagentic/core/OAMediaRef.gd`:
   - `encode_v1(dict) -> String`
   - `decode_v1(text) -> {ok:bool, ref?:Dictionary, error?:String}`
   - enforce maximum payload length (≤512 chars) and allowed `kind/mime`
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/addons/openagentic/test_media_ref_parser.gd
```

### Slice 2 — Media service skeleton (REQ-003/004)

1) **Red**: add a tiny smoke check test (or scripted check) to assert:
   - server rejects unauthenticated download
   - server rejects wrong MIME
2) **Green**: add `media_service/`:
   - `server.mjs` with `--help` and env-configured bearer token
   - `POST /upload` + `GET /media/:id`
   - magic sniff + allowlist + size limits (image≤8MiB, audio≤20MiB, video≤64MiB)
3) **Verify**:

```bash
node media_service/server.mjs --help
```

### Slice 3 — Dialogue image rendering + cache (REQ-005/006)

1) **Red**: `tests/projects/vr_offices/test_vr_offices_dialogue_media_image.gd`:
   - inject a message containing a valid `OAMEDIA1` image ref
   - verify the UI creates an image node (or equivalent) and not just text
2) **Green**:
   - parse assistant/user message text for refs
   - download into per-save cache
   - verify `sha256/bytes` then render `TextureRect` in the bubble
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_media_image.gd
```

### Slice 4 — Agent media tools (REQ-007/008)

1) **Red**: `tests/addons/openagentic/test_tool_media_upload_fetch.gd` asserts:
   - path traversal is rejected
   - returned file paths are workspace-relative
2) **Green**: implement tools:
   - `MediaUpload` reads a workspace file and uploads to media service, returning `OAMEDIA1 ...`
   - `MediaFetch` downloads by `id` into workspace cache and returns a workspace path
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/addons/openagentic/test_tool_media_upload_fetch.gd
```

### Slice 5 — IRC transport rules + bridge handling (REQ-009)

1) **Red**: `tests/projects/vr_offices/test_irc_media_ref_transport.gd` covers:
   - message length constraints (fit under desk defaults like ~360 chars, or fragment with reassembly)
   - no conflict with `OA1 `
2) **Green**:
   - implement encode/decode helpers
   - update desk channel bridge to pass through or handle `OAMEDIA1` safely
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_irc_media_ref_transport.gd
```

## Risks

- Godot MP4 playback viability: confirm early; if not supported in target builds, keep MP4 as “download-only” and defer playback.
- Tool schema + payload size: keep `OAMEDIA1` payload small (IRC + log constraints), enforce maximum length in parser.
- Security footguns: never put bearer tokens into the message payload; keep auth in config/env only.
