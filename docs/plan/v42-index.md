<!--
  v42 — Rust daemon: OA1 RPC server (REQ→RES/ERR) + optional bash executor
-->

# v42 — Rust Remote Daemon: OA1 RPC Server + Optional Bash Executor

## Vision (this version)

- The Rust daemon can act as the **remote half** of the v40 OA1 IRC-RPC transport:
  - Receive OA1 `REQ` frames via IRC `PRIVMSG`
  - Reassemble chunked requests (`seq`, `more=1/0`) with timeouts + size limits
  - Produce chunked OA1 `RES` / `ERR` replies
- The daemon keeps a **safe default** execution mode:
  - Default executor: `echo` (no command execution; useful for dry runs/tests)
  - Optional executor: real `bash -lc <command>` enabled only via explicit flag/env

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | OA1 codec (Rust) | escape/unescape, UTF‑8 byte chunking, frame parse/make | `cd remote_daemon && cargo test` | done |
| M2 | OA1 server (Rust) | REQ reassembly + RES/ERR chunked replies + limits | `cd remote_daemon && cargo test` | done |
| M3 | Daemon wiring | Joined channels handle OA1 requests end-to-end | Manual (live IRC) | done |

## Plan Index

- `docs/plan/v42-rust-daemon-oa1-server.md`

## Evidence

Green:

- `cd remote_daemon && cargo test` (PASS)
- `scripts/run_godot_tests.sh --suite vr_offices` (PASS)
- `scripts/run_godot_tests.sh --suite openagentic` (PASS)
