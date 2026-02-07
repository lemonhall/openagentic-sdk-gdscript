# PRD: Python Tk IRC client (monitor .env IRC server)

Date: 2026-02-07

## Summary

A small, local Python + Tkinter IRC client for monitoring messages on an IRC server configured via `.env`.

## Non-goals

- Not a full-featured IRC client (no DCC, no rich formatting, no scripts/plugins).
- Not a bouncer/proxy (no server-side storage).
- Not a secure secrets manager (reads `.env` from disk; does not write secrets).

## Requirements

- REQ-001: Read connection settings from `.env` (server, port, SSL flag).
- REQ-002: Connect/disconnect from the IRC server and show connection status.
- REQ-003: List channels via `LIST` and present results in a UI list.
- REQ-004: Join a selected channel via `JOIN` and show channel messages.
- REQ-005: Keep connection alive (`PING`/`PONG`) and display server/system lines.
- REQ-006: Provide basic automated verification (unit tests + a no-network self-test mode).
- REQ-007: After joining a channel, list users in the channel via `NAMES` and display them in the UI.

## Acceptance

- With a valid `.env`, the user can connect, run `LIST`, select a channel, join it, and see incoming messages in the UI.
- After joining, the user can fetch and view the channel user list (via `NAMES`).
- `python scripts/irc_tk_client.py --self-test` exits with code 0.
