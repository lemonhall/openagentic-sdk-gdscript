# v40 — IRC RPC Transport (OA1) for Desk-Bound Remote Tools

This document specifies a small, transport-level protocol layered on top of IRC `PRIVMSG` so VR Offices can treat a desk IRC channel as a **reliable-enough request/response pipe** with:

- request correlation (`req_id`)
- chunked streaming responses (`seq`, `more=1/0`)
- chunked requests (same mechanism)
- guardrails (timeouts, max sizes, filtering)

The protocol layer is **framework code**. LLMs (local NPC or remote agent) should not need to understand any of the framing/chunking rules.

---

## 1) Constraints (IRC reality)

- **Hard line limit:** IRC messages are limited to **512 bytes per line** including `CRLF`. Servers will enforce this and may truncate or drop long lines.
- **UTF‑8:** payloads are UTF‑8; we must chunk by **bytes**, and we must avoid splitting in the middle of a UTF‑8 codepoint.
- **Flood limits:** sending many `PRIVMSG` lines quickly may trigger server flood protection; pacing/throttling is needed.
- **Noise:** channels may contain non-protocol messages. Receivers must ignore everything that does not match OA1 frames.
- **Ordering:** IRC over TCP is ordered per connection, but channels are interleaved with other users; we still want `seq` for robust reassembly and debugging.

Non-goals (for v40 spec):

- Strong authentication/encryption.
- Perfect delivery across disconnect/reconnect (exactly-once).
- Multi-line rich formatting preservation (we treat output as escaped text).

---

## 2) Protocol overview

We define a single-line “frame” embedded in the IRC `PRIVMSG` trailing text:

```
OA1 <TYPE> <REQ_ID> <SEQ> <MORE> <PAYLOAD>
```

Where:

- `TYPE` is one of: `REQ`, `RES`, `ERR`, `CANCEL` (optional).
- `REQ_ID` correlates a request and its response stream.
- `SEQ` is a 1-based integer, increasing by 1 for each chunk of the same stream.
- `MORE` is `1` if more chunks will follow, else `0` for the final chunk.
- `PAYLOAD` is UTF‑8 text with escaping (section 3).

### 2.1 Frame parsing rule

Split the line into **at most 6 parts** by ASCII space:

- parts[0] = `OA1`
- parts[1] = `TYPE`
- parts[2] = `REQ_ID`
- parts[3] = `SEQ`
- parts[4] = `MORE`
- parts[5] = `PAYLOAD` (may contain spaces; may be empty)

Receivers ignore frames that do not match this shape.

### 2.2 Identifiers

`REQ_ID` should be short and collision-resistant per channel:

- recommended: 10–16 chars base32/base36, e.g. `7k3p2d9m1q`
- allowed charset: `[A-Za-z0-9_-]`

---

## 3) Payload escaping (readable mode)

We want payloads that are human-readable in the channel, but can safely contain newlines and backslashes.

### 3.1 Encoding

When sending a payload string:

1) Replace `\` with `\\`
2) Replace `\r` with `\\r`
3) Replace `\n` with `\\n`

Optional (recommended for stability):

- Replace `\t` with `\\t`

### 3.2 Decoding

When receiving a payload string, reverse the escapes:

- `\\n` → `\n`
- `\\r` → `\r`
- `\\t` → `\t`
- `\\\\` → `\`

Notes:

- Decode in an order that does not double-expand (e.g., handle `\\\\` last or use a small state machine).
- The protocol does not attempt to preserve all control characters; it is intended for typical command output.

---

## 4) Chunking rules (bytes, not characters)

We must keep each IRC line safely under 512 bytes after server-added prefix overhead. We therefore define **a conservative maximum payload size per frame**.

### 4.1 Recommended limits

- `MAX_FRAME_PAYLOAD_BYTES = 240` (default)
- `MAX_MESSAGE_AGGREGATE_BYTES = 128 * 1024` (hard cap per request/response stream)
- `REQUEST_TIMEOUT_SEC = 30` (tool waits for response completion)
- `PARTIAL_TIMEOUT_SEC = 10` (drop partial reassembly if idle)

These values should be configurable.

### 4.2 Byte-safe UTF‑8 chunking

When chunking a UTF‑8 string into payload frames:

- Work in bytes (`PackedByteArray` from `String.to_utf8_buffer()`).
- When choosing a cut position, ensure you do not cut in the middle of a UTF‑8 codepoint:
  - if the cut lands on a UTF‑8 continuation byte (`10xxxxxx`), step backwards until you hit a non-continuation byte.
- Convert each chunk back to string via UTF‑8 decode.

### 4.3 Chunk ordering and duplicates

Receivers should tolerate:

- duplicate chunks (ignore if already stored for that `seq`)
- missing chunks (treat as error/timeout; do not hang forever)

---

## 5) Request stream semantics (`TYPE=REQ`)

The request is a stream of one or more frames:

```
OA1 REQ <id> 1 1 <payload...>
OA1 REQ <id> 2 0 <payload...>
```

Receiver (“server” side) must:

- reassemble request payload for a given `<id>` by `seq`
- only dispatch the request when the final chunk arrives (`more=0`)
- enforce `MAX_MESSAGE_AGGREGATE_BYTES`
- enforce `PARTIAL_TIMEOUT_SEC` for incomplete requests

This allows the **local tool to send large requests** safely.

---

## 6) Response stream semantics (`TYPE=RES`)

The response is a stream of one or more frames:

```
OA1 RES <id> 1 1 <payload...>
OA1 RES <id> 2 1 <payload...>
OA1 RES <id> 3 0 <payload...>
```

Receiver (“client/tool” side) must:

- accept chunks for an in-flight `<id>` and reassemble by `seq`
- complete when it receives the chunk with `more=0`
- enforce `MAX_MESSAGE_AGGREGATE_BYTES` (truncate + mark `truncated=true`)
- enforce `REQUEST_TIMEOUT_SEC`

This supports **streaming** without needing `total`.

---

## 7) Errors (`TYPE=ERR`)

Errors should be correlated to the request id and sent as a final chunk (`more=0`).

Recommended shape:

```
OA1 ERR <id> 1 0 <code>: <message>
```

Examples:

- `OA1 ERR 7k3p2d9m1q 1 0 timeout: remote execution exceeded 30s`
- `OA1 ERR 7k3p2d9m1q 1 0 too_large: output exceeded 128KiB`

Client behavior:

- treat `ERR` as completion of the request
- surface error in tool result as `{ "ok": false, "error": "...", "message": "...", ... }`

---

## 8) Cancellation (`TYPE=CANCEL`, optional)

Client may cancel an in-flight request:

```
OA1 CANCEL <id> 1 0 <reason>
```

Server side may ignore it (v40 does not require remote cancellation), but including the message makes future upgrades easier.

---

## 9) Filtering and trust model

At minimum, both sides must filter:

- IRC command must be `PRIVMSG`
- target must match the desk’s desired channel
- trailing must begin with `OA1 `

Assumption (current product design): the desk channel is **dedicated** (only the remote agent/bot is present). Under this assumption we treat OA1 frames as trusted-enough and we do not require signatures.

Recommended additional filters (configurable):

- accept frames only from a configured `allowed_sender_nick`
- ignore frames from our own desk nick (loop prevention)

Security note:

- In shared channels, other users could spoof `OA1 RES ...`. If this matters, add a shared secret or signature later (out of scope for v40).

---

## 10) Tool contract: `RemoteBash` (illusion: “just Bash”)

Goal: the local NPC should experience this as a typical “Bash tool”:

- It runs a shell command on a remote machine.
- It returns a single best-effort text result (the remote side may be an agent, not a raw shell).
- The NPC should not need to care where it runs (“楚门的世界”): it’s just a tool.

Important nuance: the “remote side” may be an **agent** (with its own reasoning + history), not a raw shell. This design intentionally hides that: the *tool contract* pretends it is Bash, while the remote agent can decide how to execute it (direct shell, helper tools, etc.).

### 10.1 Recommended tool name + schema (local NPC side)

Tool name: `RemoteBash`

Input schema:

```json
{
  "type": "object",
  "properties": {
    "command": { "type": "string", "description": "The shell command to run on the remote machine." },
    "timeout_sec": { "type": "integer", "description": "Optional timeout (seconds)." }
  },
  "required": ["command"]
}
```

Output shape (v40):

The tool returns a **single string** (the decoded, reassembled OA1 `RES` stream payload).

If output is truncated due to limits, append a human-readable marker such as:

```json
"...\n...[truncated]..."
```

### 10.2 Prompt guidance (tool description)

The tool description should teach the model the constraints:

- Output may be chunked and/or truncated due to IRC limits.
- Prefer commands that keep output small (`head`, `tail`, `rg -n`, `sed -n '1,120p'`, redirect big output to files).
- If you need structured output, request JSON from the command itself (as text).

### 10.3 Stateless vs sessionful execution (design choice)

There are two viable semantics for `RemoteBash`:

**A) Stateless (one-shot)**

- Each tool call is independent.
- The remote side should execute the command as if it were run in a fresh shell context.
- No implicit carry-over of `cwd`, environment variables, shell functions, background jobs, etc.
- The remote agent can still keep *its own* conversation/history, but the tool consumer should not assume a persistent shell state.

Pros:

- Simple, deterministic, easy to test and to recover from disconnects.
- Avoids “mysterious state” bugs (`cd`/`export`/shell options leaking across calls).

Cons:

- Multi-step workflows need explicit context in the command itself (`cd /x && ...`).

**B) Sessionful (stateful)**

- Tool calls share a remote “shell session” keyed by a `session_id`.
- `cwd`/env and potentially a long-running shell process may persist.
- Supports interactive-like workflows and long tasks more naturally.

Pros:

- Convenient for incremental work (`cd`, edit, run, inspect, repeat).

Cons:

- Much more complexity: lifecycle, cleanup, timeouts, concurrency, reconnect behavior.
- Harder to make tests stable (state leaks).

**Recommended starting point (v40):** implement **stateless** semantics first. If needed, add explicit inputs like `cwd` and `env` later without committing to a persistent shell process.

**Decision (confirmed):** v40 uses **stateless (one-shot)** semantics.

### 10.3 Desk-bound visibility (important behavior)

The model should only see `RemoteBash` when the NPC is **currently desk-bound**.

Implementation note (future work):

- `OAAgentRuntime` currently sends *all registered tools* in every request (`_tool_schemas()` has no context filtering).
- To truly “hide” the tool when unbound, we will need **dynamic tool schema filtering** based on per-NPC state (not just runtime blocking via hooks).

---

## 11) Implementation sketch (future)

Local (VR Offices):

- `IrcRpcCodec`: encode/decode OA1 frames, escaping, byte-safe chunking
- `DeskIrcRpcClient`: attaches to `DeskIrcLink.message_received`, sends `REQ` frames, waits for `RES/ERR`, reassembles by id
- `RemoteBash` tool: calls `DeskIrcRpcClient.request(command)` and returns structured result
- Tool gating: only inject tool schema when `NpcBindIndicator.get_bound_npc_id() == npc_id`

Remote:

- `IrcRpcServer`: listens on channel, reassembles `REQ`, dispatches to executor
- `RemoteBashExecutor`: runs command (directly or via a remote agent), streams output back as `RES`

Tests:

- Unit tests for codec chunking + escaping (especially UTF‑8 + byte limits)
- VR Offices integration: bind/unbind toggles tool availability; request/response works with fake IRC
