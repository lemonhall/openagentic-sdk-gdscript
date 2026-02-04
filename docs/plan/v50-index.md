<!--
  v50 — VR Offices: Multimedia Messages (foundation)
-->

# v50 — Multimedia Messages (Dialogue + IRC) — Foundation

## Vision (this version)

- Land a PRD + versioned plan for “multimedia messages”.
- Define a stable **text-based** media reference (`OAMEDIA1 ...`) that can traverse:
  - VR Offices `DialogueOverlay` (NPC dialogue)
  - IRC message transport (pure text)
- Start with **image (PNG/JPEG)** end-to-end as the first verifiable slice; audio/video are planned as follow-ups.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M0 | Docs | PRD exists with Req IDs; v50 plan links Req IDs; scope/phasing is explicit | `git diff` | todo |
| M1 | Protocol | `OAMEDIA1` format + parser with strict validation (allowlist + ≤512 chars); unit tests cover valid/invalid cases | `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_media_ref_parser.gd` | todo |
| M2 | Service (skeleton) | Separate media service directory (not `proxy/`); upload/download require bearer; MIME sniff + allowlist | `node media_service/server.mjs --help` | todo |
| M3 | Dialogue (image) | DialogueOverlay renders image attachments with local cache + integrity checks; regression test | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_media_image.gd` | todo |
| M4 | Agent tools | `MediaUpload` + `MediaFetch` tools enforce workspace sandbox and do not expose host paths | `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_tool_media_upload_fetch.gd` | todo |
| M5 | IRC transport | IRC payload rules + bridge handling for `OAMEDIA1` (no OA1 conflict; fit under ~360 chars or fragment/reassemble); tests for encode/decode | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_irc_media_ref_transport.gd` | todo |
| M6 | E2E harness | Local IRC test server + sender tool to validate both directions without manual UI inspection | `scripts/run_godot_tests.sh --one tests/e2e/test_multimedia_flow.gd` | todo |

## Plan Index

- `docs/plan/v50-vr-offices-multimedia-messages-foundation.md`

## PRD

- `docs/prd/2026-02-04-vr-offices-multimedia-messages.md`

## Evidence

TBD (this version not executed yet).

## Gaps (next versions)

- Audio playback (MP3/WAV) UI + tests.
- Video handling (MP4): confirm Godot/target build support; otherwise keep as download/external-open.
- Multimodal model understanding: decide between “tool-side media summarization” vs “Responses multimodal input (base64)” without making media publicly accessible.
