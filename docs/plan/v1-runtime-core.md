# v1 Runtime Core — Design Notes

## Persistence model (shadow workspace)

All plugin persistence is scoped to:

`user://openagentic/saves/<save_id>/`

Per NPC, store a single continuous session:

`user://openagentic/saves/<save_id>/npcs/<npc_id>/session/events.jsonl`

This is the audit log (event sourcing) used to rebuild model input and to replay/debug behavior.

## Event model

Minimum representative events:

- `system.init` (once per NPC per save)
- `user.message`
- `assistant.message`
- `tool.use`
- `tool.result`
- `permission.question` / `permission.decision`
- `result`

Notes:

- Streaming deltas (`assistant.delta`) are streamed to the UI but should not be persisted into canonical `events.jsonl` by default (log hygiene + perf).
- `events.jsonl` is an audit/replay log, not a UI-optimized store. Any UI that needs “chat history” should:
  - tail-scan for the newest `user.message` / `assistant.message` items,
  - and avoid main-thread full-file reads/parses on interaction paths (e.g. dialogue open), to prevent frame hitches.

## Provider contract

The runtime talks to a game server / local proxy that is **OpenAI Responses API compatible**:

- `POST /v1/responses` JSON body
- `stream: true` returns SSE (`data: ...` + blank line delimiter), `[DONE]` terminator
- Event types consumed match OpenAI Responses (`response.output_text.delta`, etc.)

## Local proxy (dev)

This repo includes a minimal Node.js proxy at `proxy/server.mjs`:

- accepts `POST /v1/responses`
- forwards to `${OPENAI_BASE_URL}/responses` with `OPENAI_API_KEY`
- streams SSE through to the client

## Safety policy

Tools and file access are restricted by construction:

- Tools are registered explicitly in a `ToolRegistry` allowlist.
- File tools (memory) are restricted to the save-scoped `user://` subtree.
