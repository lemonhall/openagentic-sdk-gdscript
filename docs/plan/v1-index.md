# v1 Index — OpenAgentic Godot Runtime (GDScript)

## Vision (v1)

Deliver a **runtime-first** Godot 4 addon that:

- Runs an **agent tool loop** (LLM → tool calls → tool results → continue).
- Persists **per-save** and **per-NPC** continuous sessions as **JSONL event logs**.
- Streams model output (delta events) using an **OpenAI Responses-compatible SSE** proxy (no API keys stored in the client).
- Stores NPC + world “memory files” inside the save-scoped shadow workspace under `user://`.

## Milestones

1. **Core loop runnable (headless tests):** session store + tools + runner + runtime.
2. **Streaming via SSE:** parse OpenAI Responses SSE and surface `assistant.delta`.
3. **Save/NPC isolation:** strict path scoping under `user://openagentic/saves/<save_id>/...`.
4. **Memory injection:** world + NPC summaries are added to the prompt preamble.

## Plans

- Implementation plan: `docs/plans/2026-01-28-openagentic-godot4-runtime.md`

## Known gaps (v1)

- Automatic context compacting / summarization.
- Retrieval (vector DB / embeddings) and long-term memory policies.
- Rich “actor action” toolset; v1 focuses on minimal end-to-end.

