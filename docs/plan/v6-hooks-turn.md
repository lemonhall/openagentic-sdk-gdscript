# v6 — Turn Hooks (`BeforeTurn` / `AfterTurn`)

## Goal

Provide a first-class hook point around each dialogue turn so the game can:

- trigger NPC animations (talk/gesture/thinking/idle)
- show/hide UI “thinking…” indicators
- log analytics or drive state machines

This is the simplest hook slice that unlocks “game feel” without touching tool semantics.

## Scope

In scope:

- Add hook points:
  - `BeforeTurn` — after the user message is recorded, before the model request starts
  - `AfterTurn` — once the turn ends (`end`, `no_output`, `provider_error`, `max_steps`, etc.)
- Support both sync hooks and async hooks (`await`).
- Persist `hook.event` entries into the NPC session store.
- Expose registration methods on the `OpenAgentic` autoload.

Out of scope (future v7+):

- before/after model call hooks
- session lifecycle hooks
- compaction hooks

## Hook payloads

### `BeforeTurn`

Hook receives a payload `Dictionary`:

- `hook_point: "BeforeTurn"`
- `npc_id: String`
- `save_id: String`
- `workspace_root: String` (per-NPC)
- `user_text: String`

### `AfterTurn`

Hook receives a payload `Dictionary`:

- `hook_point: "AfterTurn"`
- `npc_id: String`
- `save_id: String`
- `workspace_root: String`
- `stop_reason: String`
- `assistant_text: String` (may be empty)

## Hook decisions (minimal)

Turn hooks are primarily for side effects. For v6, support:

- `action: String` — optional label stored into `hook.event` (e.g., `"play_anim:interact-right"`)
- `block: bool` + `block_reason: String` — optional; if blocked, the turn ends immediately with a `result` event (`stop_reason: "hook_blocked"`).
- `override_user_text: String` — optional; if provided, replaces the user text for this turn (still persists the original `user.message` event).

## Persisted hook events

Each matcher execution persists:

- `type: "hook.event"`
- `hook_point`
- `name` (matcher name)
- `matched: bool`
- `action: String`
- `ts`

## Kenney Mini Characters animations (for gameplay hooks)

The Kenney **Mini Characters 1** GLBs include embedded animations such as:

- `idle`, `walk`, `sprint`
- `interact-right`, `interact-left`
- `emote-yes`, `emote-no`
- `pick-up`, `sit`, `crouch`
- melee and kick attacks

Suggested mapping:

- `BeforeTurn` → play an `interact-*` or `emote-*` animation briefly
- `AfterTurn` → return to `idle`

Full list: `docs/vr_offices/animations.md`

## Acceptance

- Hooks can be registered and are called during a turn.
- Hook events are appended to the session store as `hook.event`.
- Tests:
  - `BeforeTurn` and `AfterTurn` run (sync + async coverage is acceptable via one of them).
  - Blocking a turn produces a `result` with `stop_reason: "hook_blocked"`.

## Files

- `addons/openagentic/hooks/OAHookEngine.gd`
- `addons/openagentic/OpenAgentic.gd`
- `addons/openagentic/runtime/OAAgentRuntime.gd`
- `tests/test_turn_hooks.gd` (new)

