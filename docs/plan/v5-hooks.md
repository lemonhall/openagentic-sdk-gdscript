# v5 — Hooks (pre/post tool use)

This repo’s Godot runtime addon includes a minimal hooks system (inspired by the Python `openagentic-sdk` hooks) to support gameplay integration.

## What hooks are for

- **Gameplay:** play an animation when an NPC runs a tool like `MoveTo`, or show “thinking” VFX while `WebFetch` is in progress.
- **Rules/safety:** block tool use that violates game logic (e.g., disallow writing outside the NPC’s workspace).
- **Rewrite:** clamp or normalize tool inputs/outputs (e.g., rewrite a requested path, redact sensitive content).

## Hook points (currently implemented)

- `PreToolUse`: runs **before** permission approval and tool execution; can rewrite/block tool input.
- `PostToolUse`: runs **after** tool execution; can rewrite/block tool output.

Each executed hook matcher emits a persisted event:

- `type: "hook.event"`
- includes `hook_point`, `name`, `matched`, `action`, `tool_use_id`, `tool_name`, `ts`

## API surface

### Low level

- `res://addons/openagentic/hooks/OAHookEngine.gd`
  - `add_pre_tool_use(name, tool_name_pattern, hook, is_async=false)`
  - `add_post_tool_use(name, tool_name_pattern, hook, is_async=false)`

Matchers use wildcard patterns and support multiple patterns joined by `|`, e.g.:

- `Read|Write|Edit`
- `Web*`
- `*`

### OpenAgentic autoload convenience

If you use the `OpenAgentic` autoload (recommended), you can register hooks via:

- `OpenAgentic.add_pre_tool_hook(...)`
- `OpenAgentic.add_post_tool_hook(...)`

## Hook return shape (decision)

A hook callable returns a `Dictionary` (or `{}` for “no-op”). Supported keys:

- `block: bool` — if true, blocks tool use/result
- `block_reason: String` — optional reason
- `override_tool_input: Dictionary` — for `PreToolUse` only
- `override_tool_output: Variant` — for `PostToolUse` only
- `action: String` — optional label stored into `hook.event`

## Async hooks

If your hook callable is a coroutine (uses `await`), set `is_async=true` when registering the matcher.

This avoids runtime errors like: “Trying to call an async function without `await`.”

