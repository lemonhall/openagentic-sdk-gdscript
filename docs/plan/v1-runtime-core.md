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
- `assistant.delta` (streaming)
- `assistant.message`
- `tool.use`
- `tool.result`
- `permission.question` / `permission.decision`
- `result`

## Provider contract

The runtime talks to a game server / local proxy that is **OpenAI Responses API compatible**:

- `POST /v1/responses` JSON body
- `stream: true` returns SSE (`data: ...` + blank line delimiter), `[DONE]` terminator
- Event types consumed match OpenAI Responses (`response.output_text.delta`, etc.)

## Safety policy

Tools and file access are restricted by construction:

- Tools are registered explicitly in a `ToolRegistry` allowlist.
- File tools (memory) are restricted to the save-scoped `user://` subtree.

