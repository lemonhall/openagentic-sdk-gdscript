# v41 — Rust Remote Daemon (Scaffold)

## Goal

Provide a small always-on Rust process that:

1) Generates (and persists) a single **device code**.
2) Connects to an IRC server.
3) Every ~30 seconds sends `LIST` and joins any channel that matches its device code (desk created first).

This is only the **pairing layer**. OA1 request handling / remote execution is future work.

## Constraints / Assumptions

- Daemon may be run multiple times on one machine; its stored data must not conflict across instances.
- We keep dependencies minimal (prefer std-only where possible) to make iteration stable.
- IRC line limit still applies (512 bytes including CRLF); our commands are short.

## Device Code

- Canonical format matches the game-side rules:
  - ASCII alphanumeric only
  - uppercase
  - length 6–16
- Daemon generates a code on first run and stores it under a per-code data directory.

## Channel Matching

Daemon joins any channel that:

- begins with `#oa_` (OpenAgentic prefix), and
- contains `_dev_<device_code>` (case-insensitive match)

This allows the game to embed `desk_id` for debugging without requiring the daemon to know it in advance.

## Acceptance

- `remote_daemon` exists as a Rust crate at repo root.
- `cargo test` passes offline.
- Running the daemon prints the device code and begins polling (manual verification for live IRC).

## Files

Create:

- `remote_daemon/Cargo.toml`
- `remote_daemon/src/main.rs`
- `remote_daemon/src/device_code.rs`
- `remote_daemon/src/irc.rs`
- `remote_daemon/src/matchers.rs`

## Steps (塔山开发循环)

1) **Red**: unit tests for:
   - device code canonicalize/validate
   - channel match predicate (find channels for a given device code)
2) **Green**: implement minimal std-only code to satisfy tests.
3) **Green**: implement a best-effort IRC client loop:
   - connect (plain TCP)
   - NICK/USER (+ optional PASS)
   - PING/PONG
   - periodic LIST, parse RPL_LIST (322) channel names, join matches
4) **Refactor**: keep modules small; isolate parsing and matching.
5) **Verify**: `cd remote_daemon && cargo test`

## Risks

- IRC servers may disable `LIST` or restrict it; fallback may be needed later (e.g., join-by-name or server-specific APIs).
- TLS is not implemented in the initial std-only scaffold; if required, we may add `rustls` later.

