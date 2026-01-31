# v40 — Desk-Bound `RemoteBash` Tool (Local Side) + OA1 IRC RPC Client

This plan implements the **local** half of the v40 design:

- OA1 framing/escaping/chunking codec
- OA1 IRC RPC client (send REQ, reassemble RES/ERR)
- a desk-bound `RemoteBash` tool that uses the bound desk’s IRC channel
- dynamic tool visibility (only appears when the NPC is desk-bound)

Remote machine / remote agent implementation is explicitly out of scope for v40.

---

## Goal

When an NPC is bound to a desk:

- the LLM sees a `RemoteBash` tool (Bash illusion, stateless, returns string)
- calling the tool sends an OA1 `REQ` stream to the desk’s IRC channel and waits for an OA1 `RES/ERR` stream back

When the NPC is unbound:

- `RemoteBash` does not appear in the tool list

---

## Scope

In scope:

- Add an **availability filter** to tool schema generation (per NPC/turn).
- Implement `OA1` codec:
  - readable escaping (`\\n`, `\\r`, `\\\\`)
  - UTF‑8 byte-safe chunking
- Implement a local OA1 RPC client that:
  - sends chunked `REQ`
  - reassembles streaming `RES` (`seq`, `more=1/0`)
  - enforces timeouts + max aggregate bytes
- Add `RemoteBash` tool:
  - stateless, input = `command` (+ optional timeout)
  - output = single string (aggregated text; may include `...[truncated]...`)
- Ensure the existing v39 desk channel bridge ignores OA1 protocol frames (avoid loops).

Out of scope:

- Remote agent/server implementation.
- Authentication/signatures.
- Persistent “sessionful shell” semantics.

---

## Acceptance

1) `RemoteBash` is present in OpenAI tool schemas **only** when the NPC is desk-bound.
2) `RemoteBash` sends OA1 `REQ` frames and returns aggregated OA1 `RES` text.
3) IRC messages whose trailing starts with `OA1 ` do **not** trigger a v39 “desk channel → OpenAgentic turn”.

---

## Files

Core (OpenAgentic):

- Modify: `addons/openagentic/core/OATool.gd` (availability hook)
- Modify: `addons/openagentic/runtime/OAAgentRuntime.gd` (filter tool schemas per NPC/turn)
- Test: `tests/addons/openagentic/test_tool_availability_filter.gd`

VR Offices:

- Add: `vr_offices/core/irc/OA1IrcRpcCodec.gd`
- Add: `vr_offices/core/irc/OA1IrcRpcClient.gd`
- Add: `vr_offices/core/agent/VrOfficesRemoteTools.gd` (register `RemoteBash`)
- Modify: `vr_offices/core/agent/VrOfficesAgentBridge.gd` (register remote tools)
- Modify: `vr_offices/furniture/DeskNpcDeskChannelBridge.gd` (ignore OA1 frames)
- Tests:
  - Add: `tests/projects/vr_offices/test_vr_offices_remote_bash_tool_visibility.gd`
  - Add: `tests/projects/vr_offices/test_vr_offices_oa1_irc_rpc_client_roundtrip.gd`
  - Add: `tests/projects/vr_offices/test_vr_offices_oa1_irc_rpc_codec_smoke.gd`
  - Modify: `tests/projects/vr_offices/test_vr_offices_desk_npc_bind_indicator_smoke.gd` (ignore OA1 frames regression)

---

## Steps (塔山开发循环)

### 1) Red

- Add failing tests:
  - OpenAgentic: a tool with `is_available(ctx)=false` must not appear in `req.tools`.
  - VR Offices: `RemoteBash` appears only when desk-bound.
  - VR Offices: OA1 frames do not trigger the v39 desk channel bridge.
  - VR Offices: OA1 client reassembles streamed responses and respects `more=0`.

Run (single tests):

```bash
scripts/run_godot_tests.sh --one tests/addons/openagentic/test_tool_availability_filter.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_remote_bash_tool_visibility.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_oa1_irc_rpc_client_roundtrip.gd
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_oa1_irc_rpc_codec_smoke.gd
```

### 2) Green

- Implement minimal availability filtering in OpenAgentic runtime.
- Implement codec + client.
- Implement `RemoteBash` tool + registration into OpenAgentic from VR Offices.
- Update desk channel bridge to ignore OA1 frames.

Re-run the same tests and expect PASS.

### 3) Refactor (still green)

- Extract any overly-long functions.
- Keep modules focused and < ~200 LOC.

---

## Risks

- UTF‑8 byte chunking bugs (splitting codepoints) → mitigate with unit tests and conservative payload limits.
- Tool visibility in Responses schemas requires core runtime filtering (not just runtime blocking) → covered by OpenAgentic test.
- IRC flooding from chunking → mitigate with conservative chunk size + optional pacing (future).
