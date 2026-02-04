<!--
  v52 — v50 alignment fixes: Dialogue auto-download + stronger verification
-->

# v52 — v50 Alignment Fixes (Dialogue auto-download + verification)

## Why (problem statement)

We re-read v50 PRD + v50 plan and found 3 mismatches between “doc DoD” and reality:

1) v50 plan says `DialogueOverlay` downloads media into per-save cache and verifies `bytes/sha256`, but the implementation only loads from cache and shows a placeholder when missing.
2) v50 plan’s media service verification was too soft (only `--help`), not a behavior smoke check.
3) v50 index says E2E validates both directions, but the current E2E focuses on tool-side upload→IRC→fetch into workspace.

This version fixes those gaps with tests + evidence.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Dialogue | Missing/invalid cached image triggers download to per-save cache; verifies sha/bytes; shows deterministic error on failure | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_media_image_download.gd` | todo |
| M2 | Media service | Real server smoke check validates auth + MIME sniff behavior | `node media_service/smoke_test.mjs` | todo |
| M3 | E2E | Extend E2E to also validate “remote → player cache” path using the same local IRC + transport | `scripts/run_godot_tests.sh --one tests/e2e/test_multimedia_flow.gd` | todo |

## PRD Trace

- REQ-005, REQ-006 (client render + cache)
- REQ-004 (service security)
- REQ-009 (IRC constraints)

PRD: `docs/prd/2026-02-04-vr-offices-multimedia-messages.md`

## Plan Index

- `docs/plan/v52-v50-alignment-dialogue-download-and-e2e.md`

## Evidence

TBD.

