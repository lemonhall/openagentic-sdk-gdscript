# v42 — Rust Daemon OA1 Server (Remote Side)

## Goal

Make `remote_daemon` capable of responding to the game’s desk-bound `RemoteBash` tool by implementing the remote half of OA1 IRC RPC:

- Receive OA1 chunked `REQ` frames (payload is the bash command string).
- Reassemble request text by `(req_id, seq)`.
- Execute via an executor:
  - default: `echo` (safe, no command execution)
  - optional: `bash -lc` (explicitly enabled)
- Send OA1 chunked `RES` frames (or `ERR` for timeouts/too-large/internal errors).

## Security Note

OA1 over IRC has **no authentication**. Anyone in the channel could send OA1 frames.

In v42 we keep bash execution **opt-in** (flag/env). If you enable it, treat the IRC server/channel as trusted/private.

## Acceptance

- Unit tests cover:
  - OA1 escaping/unescaping and byte-safe chunking
  - Frame parse/make roundtrip
  - REQ reassembly (seq ordering, missing chunks) and response chunking
- `remote_daemon` main loop can:
  - join matching `_dev_<device_code>` channels (v41)
  - handle OA1 requests in those channels

## Files

Modify:

- `remote_daemon/src/main.rs`
- `remote_daemon/src/irc.rs`

Add:

- `remote_daemon/src/oa1.rs`
- `remote_daemon/src/rpc.rs`

## Steps (塔山开发循环)

1) **Red**: add failing unit tests for OA1 codec + RPC reassembly.
2) **Green**: implement `oa1.rs` (codec) until tests pass.
3) **Green**: implement `rpc.rs` (reassembly + response chunking) until tests pass.
4) **Green**: wire into `irc.rs` loop:
   - parse `PRIVMSG` lines
   - accept only `TYPE=REQ`
   - reply to the same channel
5) **Verify**: `cd remote_daemon && cargo test`

## Risks

- IRC flood limits: chunking can emit many `PRIVMSG`. Mitigate later with pacing/backpressure.
- Ordering/duplication: reassembly must be robust against duplicate or out-of-order frames.

