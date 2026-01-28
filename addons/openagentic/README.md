# OpenAgentic (Godot 4 runtime addon)

This addon ports the **core runtime loop** from `openagentic-sdk-ts` into GDScript:

- event-sourced per-NPC sessions (JSONL)
- tool registry + permission gate + tool runner
- agent runtime loop with **streaming** deltas
- OpenAI Responses-compatible **SSE** provider via your own proxy

## Persistence layout

Everything is scoped under `user://openagentic/` (per-save “shadow workspace”):

- `user://openagentic/saves/<save_id>/npcs/<npc_id>/session/events.jsonl`
- `user://openagentic/saves/<save_id>/shared/world_summary.txt` (optional)
- `user://openagentic/saves/<save_id>/npcs/<npc_id>/memory/summary.txt` (optional)

## Quick start (runtime)

1. Add `res://addons/openagentic/OpenAgentic.gd` as an Autoload singleton named `OpenAgentic`.
2. Configure it at runtime:

```gdscript
OpenAgentic.set_save_id("slot1")
OpenAgentic.configure_proxy_openai_responses("https://your-proxy.example/v1", "gpt-4.1-mini", "authorization", "<token>", true)
OpenAgentic.set_approver(func(_q, _ctx): return true) # or implement your own policy/UI
OpenAgentic.register_tool(OATool.new("echo", "echo input", func(input, _ctx): return input))
```

3. Run a turn (stream events):

```gdscript
await OpenAgentic.run_npc_turn("npc_blacksmith_001", "Hello", func(ev: Dictionary) -> void:
	print(ev)
)
```

## Tests

This repo includes headless test scripts under `tests/` intended to run locally:

```bash
godot4 --headless --script tests/test_sse_parser.gd
```

