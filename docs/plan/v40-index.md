<!--
  v40 — Desk IRC RPC transport (OA1) + desk-bound RemoteBash tool design
-->

# v40 — Desk IRC RPC Transport (OA1) + Desk-Bound RemoteBash Tool

## Vision (this version)

- Define a **transport-level protocol** on top of IRC `PRIVMSG` so we can reliably do request/response:
  - `req_id` correlation
  - **streaming chunked responses** (`more=1/0`, `seq`)
  - chunked requests (same mechanism)
  - timeouts + max-size guards + basic sender/channel filtering
- The protocol layer is **framework code**; neither local NPC LLM nor remote agent LLM needs to care about IRC framing details.
- Define a desk-bound tool UX:
  - NPC sees `RemoteBash` **only while desk-bound** (bind → tool appears; unbind → tool disappears).
  - Tool execution == send OA1 frames to the bound desk IRC channel, wait for OA1 response, return aggregated output.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Protocol spec | OA1 message formats + escaping + chunking rules + state machines | Read doc | done |
| M2 | Tool contract | `RemoteBash` schema + prompt guidance + gating rules | Read doc | done |
| M3 | Local implementation | Codec + local client + `RemoteBash` tool + dynamic tool visibility + tests | `scripts/run_godot_tests.sh --suite openagentic` + `scripts/run_godot_tests.sh --suite vr_offices` | done |
| M4 | Remote implementation (future) | Remote IRC server/agent + executor + RPC request handling | (TBD) | todo |

## Plan Index

- `docs/plan/v40-irc-rpc-transport.md`
- `docs/plan/v40-remote-bash-tool.md`

## Evidence

Green (headless, Godot 4.6):

- `scripts/run_godot_tests.sh --suite openagentic` (PASS)
- `scripts/run_godot_tests.sh --suite vr_offices` (PASS)
