# v1 Index — OpenAgentic Godot Runtime (GDScript)

## Vision (v1)

Deliver a **runtime-first** Godot 4 addon that:

- Runs an **agent tool loop** (LLM → tool calls → tool results → continue).
- Persists **per-save** and **per-NPC** continuous sessions as **JSONL event logs**.
- Streams model output (delta events) using an **OpenAI Responses-compatible SSE** proxy (no API keys stored in the client).
- Stores NPC + world “memory files” inside the save-scoped shadow workspace under `user://`.

## Milestones (facts panel)

1. **Core loop runnable (headless tests):** session store + tools + runner + runtime. (done)
2. **Streaming via SSE:** OpenAI Responses-compatible SSE parsing + streaming deltas. (done)
3. **Save/NPC isolation:** strict path scoping under `user://openagentic/saves/<save_id>/...`. (done)
4. **Memory injection:** world + NPC summaries are added to the prompt preamble. (done; optional files)
5. **Local proxy + runnable demo:** Node proxy + in-engine chat UI to talk to `npc_1`. (done)

## Plans

- Implementation plan: `docs/plans/2026-01-28-openagentic-godot4-runtime.md`

## Definition of Done (DoD)

- A local proxy exists that exposes `POST /v1/responses` and streams SSE.
- The demo scene can send a message to `npc_1` and render streaming output.
- Sessions are persisted per save + per NPC under `user://openagentic/saves/<save_id>/...`.

## Verification (local)

Proxy:

- Run: `OPENAI_API_KEY=... node proxy/server.mjs`
- Verify: `curl http://127.0.0.1:8787/healthz`

Godot headless scripts:

- Run: `godot4 --headless --script tests/test_sse_parser.gd`
- Run: `godot4 --headless --script tests/test_session_store.gd`
- Run: `godot4 --headless --script tests/test_tool_runner.gd`
- Run: `godot4 --headless --script tests/test_agent_runtime.gd`

Manual demo:

- Start proxy, open the Godot project, type in the demo UI, observe streaming deltas.

## Known gaps (v1)

- Automatic context compacting / summarization.
- Retrieval (vector DB / embeddings) and long-term memory policies.
- Rich “actor action” toolset; v1 focuses on minimal end-to-end.
- Plan drift: `docs/plans/2026-01-28-openagentic-godot4-runtime.md` mentions `OAMemory.gd` + `tests/test_memory_injection.gd`, but v1 currently injects memory directly in `OAAgentRuntime.gd` and does not include that test script yet.
- Verification in this sandbox is limited (no `godot4`, and binding a local TCP port for the proxy can be blocked); run the verification commands locally.
