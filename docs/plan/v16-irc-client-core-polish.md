# v16 Plan (Follow-up) — IRC Client Core Polish

## Goal

Close remaining v16 gaps so the addon matches the “traditional core IRC over plain TCP” vision in production-relevant behaviors:

- Byte-robust framing under arbitrary TCP chunking.
- A single reusable “message → wire line” formatter (emit correctness).
- Clean disconnect API (`QUIT` + close).
- Standard Godot addon packaging metadata + minimal usage docs.

## Scope

- Keep v16 features only (core IRC): NICK/USER + JOIN/PART + PRIVMSG/NOTICE + PING/PONG + disconnect.
- No new protocol surface beyond v16 (TLS/IRCv3/CTCP are out-of-scope for this plan file; if present, they must remain opt-in and not regress v16).

## Acceptance

1) **Byte-safe framing**
- Given UTF-8 payload split across arbitrary chunks (including splitting inside multibyte codepoints), the line buffer yields exact original lines once terminated by `\n` (tolerating optional preceding `\r`).

2) **Wire formatting**
- Given `{command, params, trailing}`, formatter outputs a valid IRC line:
  - Middle params separated by single spaces.
  - Trailing emitted only when non-empty; emitted as `:<trailing>` and may contain spaces.
  - The result never contains embedded `\r` or `\n`.

3) **Clean disconnect**
- Client exposes:
  - `close_connection()` which closes the transport.
  - `quit(reason := "")` which sends `QUIT` (with optional trailing reason) then closes.
- These APIs are testable against an in-memory peer (no real sockets required).

4) **Addon packaging/docs**
- `addons/irc_client/plugin.cfg` exists with minimal metadata.
- `addons/irc_client/README.md` includes a minimal usage example (instantiate, connect, poll in `_process`, basic send, signals).

## Files

Modify:
- `addons/irc_client/IrcLineBuffer.gd`
- `addons/irc_client/IrcClient.gd`
- `addons/irc_client/README.md`

Add:
- `addons/irc_client/IrcWire.gd`
- `addons/irc_client/plugin.cfg`
- `addons/irc_client/plugin.gd`
- `tests/addons/irc_client/test_irc_wire_format.gd`
- `tests/addons/irc_client/test_irc_disconnect.gd`

Update (index only):
- `docs/plan/v16-index.md`

## Steps (塔山开发循环)

### 1) Red: byte-safe framing

- Add/extend `tests/addons/irc_client/test_irc_line_buffer.gd`:
  - Feed `PackedByteArray` chunks where a multibyte UTF-8 character is split across chunks, and assert the reconstructed line matches exactly.
- Run; expect FAIL (current buffer is String-based).

### 2) Green: byte-safe line buffer

- Update `addons/irc_client/IrcLineBuffer.gd` to buffer bytes and split by `\n`.
- Keep a small compatibility wrapper for existing string tests if needed.
- Run; expect PASS.

### 3) Red: wire formatting

- Add `tests/addons/irc_client/test_irc_wire_format.gd` covering:
  - `PING` with trailing
  - `PRIVMSG #c :hello world`
  - Reject/strip embedded CR/LF in user-provided segments
- Run; expect FAIL (no formatter yet).

### 4) Green: wire formatting implementation

- Add `addons/irc_client/IrcWire.gd` with a small API:
  - `format(command: String, params: Array[String], trailing: String) -> String`
- Update `IrcClient` helpers to use the formatter (single source of truth).
- Run; expect PASS.

### 5) Red: disconnect / quit

- Add `tests/addons/irc_client/test_irc_disconnect.gd` using an in-memory peer to assert:
  - `quit("bye")` sends a `QUIT :bye` line and then closes.
  - `close_connection()` closes without sending.
- Run; expect FAIL.

### 6) Green: implement disconnect APIs

- Implement `close_connection()` / `quit()` in `addons/irc_client/IrcClient.gd`.
- Ensure `disconnected` signal semantics remain consistent.
- Run; expect PASS.

### 7) Refactor + packaging/docs

- Add `plugin.cfg`/`plugin.gd` and README usage.
- Keep scripts small (<~200 LOC); extract helpers if `IrcClient.gd` grows.

### 8) Verify

- Run all IRC tests headless with `timeout`.
- Record evidence in `docs/plan/v16-index.md` (Evidence section).

## Risks

- UTF-8 boundary handling: mitigate by testing a split multibyte character.
- Disconnect semantics differ between real sockets and in-memory peers: mitigate by ensuring API closes the underlying peer via a single method, and by keeping the test peer behavior minimal and deterministic.
