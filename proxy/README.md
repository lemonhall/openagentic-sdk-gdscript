# Local Proxy (OpenAI Responses SSE)

This is a tiny dependency-free Node.js proxy for Godot clients.

It accepts:

- `POST /v1/responses` (streaming SSE)

and forwards to:

- `${OPENAI_BASE_URL}/responses` with `Authorization: Bearer ${OPENAI_API_KEY}`

## Run

```bash
export OPENAI_API_KEY=...
export OPENAI_BASE_URL=https://api.openai.com/v1
node proxy/server.mjs
```

Or via flags:

```bash
node proxy/server.mjs --api-key "$OPENAI_API_KEY" --base-url "https://api.openai.com/v1"
```

Defaults:

- `HOST=127.0.0.1`
- `PORT=8787`

## Godot demo env vars

The demo reads:

- `OPENAGENTIC_PROXY_BASE_URL` (default `http://127.0.0.1:8787/v1`)
- `OPENAGENTIC_MODEL` (default `gpt-5.2`)
- `OPENAGENTIC_SAVE_ID` (default `slot1`)
- `OPENAGENTIC_NPC_ID` (default `npc_1`)
