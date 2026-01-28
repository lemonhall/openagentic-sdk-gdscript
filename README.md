# OpenAgentic Godot (GDScript)

Runtime-first **Godot 4** addon that ports the core loop of `openagentic-sdk-ts` into GDScript:

- Event-sourced, per-save + per-NPC **continuous sessions** (JSONL)
- Streaming assistant output (**`assistant.delta`**) via **OpenAI Responses-compatible SSE** (through your own proxy)
- Tool calling loop (**tool registry → permission gate → tool runner**) for driving in-game Actors
- Save-scoped “shadow workspace” under `user://` for NPC/world memory files (no import/commit workflow)

## Status

Early v1 slice: minimal end-to-end core is implemented; API is expected to change.

## Installation

Copy `addons/openagentic/` into your Godot project and enable it by adding an Autoload singleton:

- Autoload name: `OpenAgentic`
- Script: `res://addons/openagentic/OpenAgentic.gd`

## Persistence layout (per save slot)

Everything is scoped to:

`user://openagentic/saves/<save_id>/`

Per NPC (single continuous “lifetime” session):

- `.../npcs/<npc_id>/session/events.jsonl`
- `.../npcs/<npc_id>/session/meta.json`

Optional memory files injected into the prompt:

- `.../shared/world_summary.txt`
- `.../npcs/<npc_id>/memory/summary.txt`

## Quick start (runtime)

```gdscript
OpenAgentic.set_save_id("slot1")

# Point to your own proxy that speaks OpenAI Responses API (SSE streaming).
OpenAgentic.configure_proxy_openai_responses(
	"https://your-proxy.example/v1",
	"gpt-4.1-mini",
	"authorization",
	"<token>",
	true
)

# Decide tool permissions (v1: allow/deny via callback).
OpenAgentic.set_approver(func(_q: Dictionary, _ctx: Dictionary) -> bool:
	return true
)

# Register tools that the model is allowed to call.
OpenAgentic.register_tool(OATool.new(
	"echo",
	"Echo input",
	func(input: Dictionary, _ctx: Dictionary):
		return input
))

await OpenAgentic.run_npc_turn("npc_blacksmith_001", "Hello", func(ev: Dictionary) -> void:
	# You’ll see assistant.delta/tool.use/tool.result/assistant.message/result events here.
	print(ev)
)
```

## Proxy requirement (SSE)

The client does **not** store a long-lived OpenAI API key. It calls your proxy endpoint:

- `POST /v1/responses` with `stream: true`
- Response is SSE with `data: ...` frames and `[DONE]` terminator

## Tests (local)

This repo includes headless test scripts under `tests/` (requires `godot4` locally):

```bash
godot4 --headless --script tests/test_sse_parser.gd
godot4 --headless --script tests/test_session_store.gd
godot4 --headless --script tests/test_tool_runner.gd
godot4 --headless --script tests/test_agent_runtime.gd
```

## Docs / Plans

- `docs/plan/v1-index.md`
- `docs/plans/2026-01-28-openagentic-godot4-runtime.md`

