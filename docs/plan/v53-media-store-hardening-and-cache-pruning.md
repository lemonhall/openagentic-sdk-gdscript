<!--
  v53 — plan: media_service hardening + store cap + client cache prune
-->

# v53 — Media Store Hardening + Cache Pruning Plan

## Goal

Make multimedia messages safer and self-cleaning:

- Prevent `media_service` path traversal / unsafe id usage.
- Enforce total media store limit with a deterministic cleanup strategy.
- Enforce per-save cache cleanup strategy (TTL + max bytes) in VR Offices.
- Update player-facing docs to match current behavior.

## PRD Trace

- REQ-004 (service security + limits)
- REQ-006 (client cache cleanup strategy)

PRD: `docs/prd/2026-02-04-vr-offices-multimedia-messages.md`

## Explicit Limits (v53)

These are v53-solidified thresholds (configurable via env):

- Media store:
  - `OPENAGENTIC_MEDIA_STORE_MAX_BYTES` default: `512 MiB`
  - `OPENAGENTIC_MEDIA_STORE_TTL_SEC` default: `0` (disabled)
  - Cleanup strategy: delete expired items (TTL), then evict **oldest-first** until under cap.
- VR Offices per-save cache:
  - `OPENAGENTIC_MEDIA_CACHE_MAX_BYTES` default: `256 MiB`
  - `OPENAGENTIC_MEDIA_CACHE_TTL_SEC` default: `0` (disabled)
  - Cleanup strategy: delete expired items (TTL), then evict **oldest-first** until under cap.

## Acceptance (DoD)

1) `GET /media/:id` rejects ids containing path separators, `..`, or other unsafe chars; must return 400.
2) With a small `OPENAGENTIC_MEDIA_STORE_MAX_BYTES`, a second upload triggers eviction of the oldest item (or returns deterministic “store full” error).
3) VR Offices cache prune deletes expired items and enforces max bytes while keeping the newest entry.
4) Updated `docs/vr_offices/multimedia_messages.zh-CN.md` no longer claims “remote images never auto-download” (since v52 added download on cache miss).

## Files

Modify:

- `media_service/server.mjs`
- `media_service/smoke_test.mjs`
- `vr_offices/ui/VrOfficesMediaCache.gd`
- `docs/vr_offices/multimedia_messages.zh-CN.md`

Add:

- `tests/projects/vr_offices/test_vr_offices_media_cache_prune.gd`

## Steps (塔山开发循环)

### Slice A — `media_service` id hardening (RED → GREEN)

1) **Red**: extend `media_service/smoke_test.mjs`:
   - `GET /media/../x` returns 400
   - `GET /media/a/b` returns 400
2) **Verify (Red)**:

```bash
node media_service/smoke_test.mjs
```

Expected: FAIL until server rejects unsafe ids.

3) **Green**: implement strict `id` validation in `media_service/server.mjs`.
4) **Verify (Green)**:

```bash
node media_service/smoke_test.mjs
```

Expected: PASS.

### Slice B — Media store total cap + cleanup (RED → GREEN)

1) **Red**: extend `media_service/smoke_test.mjs`:
   - Run server with `OPENAGENTIC_MEDIA_STORE_MAX_BYTES` tiny
   - Upload PNG twice; expect the first id to be evicted (GET returns 404) or deterministic 507/413 on second upload
2) **Green**: in `media_service/server.mjs`:
   - Add `OPENAGENTIC_MEDIA_STORE_MAX_BYTES` + `OPENAGENTIC_MEDIA_STORE_TTL_SEC`
   - On upload: cleanup expired (TTL), then evict oldest-first until enough space, else reject
3) **Verify**:

```bash
node media_service/smoke_test.mjs
```

### Slice C — VR Offices cache prune (RED → GREEN)

1) **Red**: add `tests/projects/vr_offices/test_vr_offices_media_cache_prune.gd`:
   - Write 3 cached blobs
   - Call prune with `max_bytes` smaller than total
   - Assert oldest removed, newest remains
2) **Green**: implement:
   - `VrOfficesMediaCache.prune_cache(save_id, max_bytes, ttl_sec)`
   - Call prune from `store_cached_bytes()` using env-configured defaults
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_media_cache_prune.gd
```

### Slice D — Doc alignment (still GREEN)

1) Update `docs/vr_offices/multimedia_messages.zh-CN.md` to reflect:
   - v52+ auto-download image on cache miss (player side)
2) Verify:

```bash
rg -n "自动下载" docs/vr_offices/multimedia_messages.zh-CN.md
```

