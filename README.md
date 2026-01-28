# OpenAgentic Godot (GDScript)

![Screenshot](screenshot.png)

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

This repo includes a tiny dependency-free Node.js proxy in `proxy/`:

```bash
export OPENAI_API_KEY=...
export OPENAI_BASE_URL=https://api.openai.com/v1  # optional
node proxy/server.mjs
```

## Tests (local)

This repo includes headless test scripts under `tests/` (requires `godot4` locally):

```bash
godot4 --headless --script tests/test_sse_parser.gd
godot4 --headless --script tests/test_session_store.gd
godot4 --headless --script tests/test_tool_runner.gd
godot4 --headless --script tests/test_agent_runtime.gd
```

WSL2 + Windows Godot helper script:

```bash
scripts/run_godot_tests.sh
```

## Demo (talk to the first NPC)

1. Start the proxy (above).
2. Run the Godot project.
   - Default main scene is the RPG-style demo: `res://demo_rpg/World.tscn`
   - The older “chat UI” demo remains at `res://demo/Main.tscn`

## Assets

The RPG demo uses Kenney CC0 art. If you didn't clone with assets already present, you can import them from a local zip:

```bash
scripts/import_kenney_roguelike_rpg_pack.sh
scripts/import_kenney_roguelike_characters.sh
```

See `assets/CREDITS.md`.

## Collision masks (auto draft)

For “painted background” maps, you can generate collisions from a PNG mask (opaque = obstacle):

- Generator: `python3 scripts/generate_collision_mask.py <background.png> --out <mask.png>`
- Runtime collider: `demo_rpg/collision/OACollisionFromMask.gd`

Details: `docs/collision_masks/README.md`

Demo can be configured via env vars:

- `OPENAGENTIC_PROXY_BASE_URL` (default `http://127.0.0.1:8787/v1`)
- `OPENAGENTIC_MODEL` (default `gpt-5.2`)
- `OPENAGENTIC_SAVE_ID` (default `slot1`)
- `OPENAGENTIC_NPC_ID` (default `npc_1`)

## Collision masks (auto draft)

For “painted background” maps, collisions can be generated from a PNG mask (opaque = obstacle). This repo includes:

- Generator: `python3 scripts/generate_collision_mask.py <background.png> --out <mask.png>`
- Runtime collider: `demo_rpg/collision/OACollisionFromMask.gd`

Details: `docs/collision_masks/README.md`

Optional environment variables for the demo:

- `OPENAGENTIC_PROXY_BASE_URL` (default `http://127.0.0.1:8787/v1`)
- `OPENAGENTIC_MODEL` (default `gpt-5.2`)
- `OPENAGENTIC_SAVE_ID` (default `slot1`)
- `OPENAGENTIC_NPC_ID` (default `npc_1`)

## Docs / Plans

- `docs/plan/v1-index.md`
- `docs/plan/v2-index.md`
- `docs/plan/v2-rpg-demo.md`
- `docs/plans/2026-01-28-openagentic-godot4-runtime.md`
