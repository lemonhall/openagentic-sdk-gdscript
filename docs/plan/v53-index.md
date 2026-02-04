<!--
  v53 — Media store hardening + cache pruning
-->

# v53 — Media Store Hardening + Cache Pruning

## Why (problem statement)

We need to close 3 gaps found during v50–v52 review:

1) **Security:** `media_service` download path accepts arbitrary `:id` and can be vulnerable to path traversal / unintended file reads.
2) **Service storage:** PRD requires a total storage limit + cleanup strategy; current `media_service` only enforces per-file limits.
3) **Client cache:** PRD requires a per-save cache cleanup strategy (TTL/LRU/size cap); current cache only writes bytes.

This version implements all three with hard verification.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Security | `/media/:id` rejects unsafe ids; smoke test covers traversal patterns | `node media_service/smoke_test.mjs` | done |
| M2 | Service storage | Total store cap enforced via eviction (oldest-first) + TTL cleanup | `node media_service/smoke_test.mjs` | done |
| M3 | Client cache | Per-save cache prunes by TTL and max bytes; regression test covers prune behavior | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_media_cache_prune.gd` | done |
| M4 | Docs | Player doc reflects current behavior (auto-download images since v52) | `rg -n \"自动下载\" docs/vr_offices/multimedia_messages.zh-CN.md` | done |

## PRD Trace

- REQ-004 (service security + limits)
- REQ-006 (client cache cleanup strategy)

PRD: `docs/prd/2026-02-04-vr-offices-multimedia-messages.md`

## Plan Index

- `docs/plan/v53-media-store-hardening-and-cache-pruning.md`

## Evidence

- 2026-02-04: `node media_service/smoke_test.mjs` → PASS
- 2026-02-04: `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_media_cache_prune.gd` → PASS
- 2026-02-04: `rg -n "自动下载" docs/vr_offices/multimedia_messages.zh-CN.md` → matches found
