# OpenAgentic Media Service (v0)

This service stores and serves small media blobs (image/audio/video) for OpenAgentic.

Design goals:

- **Not** colocated with `proxy/` (separate service/process).
- Requires bearer auth for upload and download.
- Sniffs MIME by magic bytes (does not trust filename or client content-type).
- Enforces strict allowlists and size limits (see PRD).

## Run

```bash
export OPENAGENTIC_MEDIA_BEARER_TOKEN="dev-token"
node media_service/server.mjs --host 127.0.0.1 --port 8788
```

Health:

```bash
curl -s http://127.0.0.1:8788/healthz
```

## Endpoints

- `GET /healthz` → `{ok:true}`
- `POST /upload` (auth required) → JSON `{ok:true, id, kind, mime, bytes, sha256, name?, caption?}`
  - Request body: raw bytes
  - Optional headers:
    - `x-oa-name`: original filename (max 128 chars)
    - `x-oa-caption`: caption (max 128 chars)
- `GET /media/<id>` (auth required) → raw bytes with headers:
  - `content-type`
  - `content-length`
  - `x-oa-sha256`
  - `x-oa-kind`

