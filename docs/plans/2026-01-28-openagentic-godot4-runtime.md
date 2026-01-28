# OpenAgentic Godot 4 Runtime Plugin Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Build a Godot 4 (GDScript) runtime addon that runs an agent tool-loop with OpenAI Responses-compatible SSE streaming via a proxy, with per-save and per-NPC isolated persistence (“shadow workspace”) under `user://`.

**Architecture:** Port the TS core loop (events + session store + tool registry/runner + permission gate + provider) into GDScript. Persist per-NPC continuous sessions as JSONL event logs scoped to a save slot directory. Provide a small `OpenAgentic` facade intended to be used as an Autoload in exported games.

**Tech Stack:** Godot 4.x, GDScript, `HTTPClient` (streaming), JSONL files via `FileAccess`.

---

## Task 1: Repository scaffold (addon + demo + docs)

**Files:**
- Create: `addons/openagentic/OpenAgentic.gd`
- Create: `addons/openagentic/README.md`
- Create: `demo/project.godot`
- Create: `demo/Main.tscn`
- Create: `demo/Main.gd`

**Step 1: Write a failing “smoke” script (RED)**

Create `demo/Main.gd` to try calling `OpenAgentic` API that does not exist yet.

Expected: running the scene fails with “identifier not found / invalid call”.

**Step 2: Minimal addon skeleton (GREEN)**

Create `OpenAgentic.gd` with stub methods used by the demo and minimal no-op behavior.

**Step 3: Manual verification**

Run locally (outside this repo’s CI): open `demo/` with Godot, press Play, confirm the scene runs (it can print placeholder output).

---

## Task 2: JSONL session store (per-save + per-NPC continuous session)

**Files:**
- Create: `addons/openagentic/core/OAJsonlNpcSessionStore.gd`
- Create: `addons/openagentic/core/OAPaths.gd`
- Create: `tests/test_session_store.gd`

**Step 1: Write failing test (RED)**

`tests/test_session_store.gd`:
- Create store for `save_id="slot1"`, append 2 events for `npc_id="npc_1"`, reload store, assert events read back in order and `seq` increases.

Expected: fails because store class does not exist.

**Step 2: Implement minimal store (GREEN)**

Implement:
- directories under `user://openagentic/saves/<save_id>/npcs/<npc_id>/session/`
- `events.jsonl` append/read
- `state.json` holding `next_seq`

**Step 3: Manual verification**

Run locally: `godot4 --headless --script tests/test_session_store.gd`

Expected: prints PASS and exits `0`.

---

## Task 3: Tool system + permission gate + tool runner

**Files:**
- Create: `addons/openagentic/core/OATool.gd`
- Create: `addons/openagentic/core/OAToolRegistry.gd`
- Create: `addons/openagentic/core/OAAskOncePermissionGate.gd`
- Create: `addons/openagentic/core/OAToolRunner.gd`
- Create: `tests/test_tool_runner.gd`

**Step 1: Write failing test (RED)**

Register a simple tool `echo` that returns input, run a tool call through the runner, assert emitted events include `tool.use` and `tool.result`.

Expected: fails (missing classes).

**Step 2: Minimal implementation (GREEN)**

- Registry with `register/get/names`
- Gate with allowlist via `approver` callback (default deny)
- Runner that records events to `SessionStore`

**Step 3: Manual verification**

Run locally: `godot4 --headless --script tests/test_tool_runner.gd`

---

## Task 4: OpenAI Responses-compatible SSE provider (via proxy)

**Files:**
- Create: `addons/openagentic/providers/OAOpenAIResponsesProvider.gd`
- Create: `addons/openagentic/providers/OASseParser.gd`
- Create: `tests/test_sse_parser.gd`

**Step 1: Write failing test (RED)**

Feed a sample SSE stream string containing:
- `response.output_text.delta`
- function call lifecycle (`response.output_item.added` + `response.function_call_arguments.delta` + `response.output_item.done`)
- `[DONE]`

Assert parsed callback yields `text_delta`, `tool_call`, and final `done`.

**Step 2: Implement parser (GREEN)**

- Line-based SSE: accumulate `data:` lines until blank line; yield joined data
- JSON parse + OpenAI Responses event mapping (like TS)

**Step 3: Manual verification**

Run locally: `godot4 --headless --script tests/test_sse_parser.gd`

---

## Task 5: Agent runtime tool loop (streaming deltas + tool execution)

**Files:**
- Create: `addons/openagentic/runtime/OAAgentRuntime.gd`
- Create: `addons/openagentic/runtime/OAReplay.gd`
- Modify: `addons/openagentic/OpenAgentic.gd`
- Create: `tests/test_agent_runtime.gd`

**Step 1: Write failing test (RED)**

Use a fake provider that:
- streams a tool call first
- then streams final assistant text after tool result exists in events

Assert:
- `assistant.delta` events appended during streaming
- tool events persisted
- final `assistant.message` + `result` appended

**Step 2: Minimal implementation (GREEN)**

- `run_turn(save_id, npc_id, user_text)` that:
  - ensures `system.init`
  - appends `user.message`
  - loops `max_steps`
  - rebuilds OpenAI Responses input from events
  - calls provider `.stream(...)` and records `assistant.delta`
  - executes tool calls via `ToolRunner`
  - writes final `assistant.message` + `result`

**Step 3: Manual verification**

Run locally: `godot4 --headless --script tests/test_agent_runtime.gd`

---

## Task 6: Memory injection (world summary + NPC summary)

**Files:**
- Modify: `addons/openagentic/runtime/OAAgentRuntime.gd`
- Create: `addons/openagentic/runtime/OAMemory.gd`
- Create: `tests/test_memory_injection.gd`

**Step 1: Write failing test (RED)**

Create `world_summary.txt` and `npcs/<npc_id>/memory/summary.txt` under the save root, assert runtime prepends a `system` input item containing both texts.

**Step 2: Minimal implementation (GREEN)**

- If files exist, load them and build a single system message block
- Keep it optional; missing files should not error

---

## Notes / Constraints

- This repo environment may not have `godot4` installed; tests are designed to run locally.
- v2+ can add automatic compacting (summaries + windowing + retrieval). Out of v1 scope.

