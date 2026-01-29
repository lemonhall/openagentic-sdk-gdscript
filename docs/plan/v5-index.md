# v5 Index — Hooks (Gameplay Integration)

## Vision (v5)

Make the Godot runtime addon extensible via **hooks** (inspired by the Python `openagentic-sdk`), so games can:

- trigger **animations / VFX / in-world behaviors** when tools are used
- **rewrite** tool inputs/outputs (e.g., clamp movement, sanitize reads)
- **block** tool usage/results for safety or game rules

## Milestones (facts panel)

1. **Async tool execution:** execute coroutine tools via `await` (WebFetch/WebSearch must not crash). (done)
2. **Hook engine:** add `OAHookEngine` with `pre_tool_use` and `post_tool_use` matchers. (done)
3. **Tool runner wiring:** call hooks before approval + after tool result; persist `hook.event` entries. (done)
4. **Tests:** hook rewrite + block coverage in `tests/`. (done)

## Plans (v5)

- `docs/plan/v5-hooks.md`

## Definition of Done (DoD)

- Tool execution supports async tools without runtime errors.
- Hooks can:
  - rewrite tool input before execution
  - rewrite tool output after execution
  - block tool execution/result
- Tests cover the behaviors and are runnable via `scripts/run_godot_tests.ps1` (Windows) or `scripts/run_godot_tests.sh` (WSL interop).

