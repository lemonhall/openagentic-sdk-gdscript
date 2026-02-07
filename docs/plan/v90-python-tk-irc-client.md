# v90: Python Tk IRC client (monitor .env IRC server)

PRD trace: `docs/prd/2026-02-07-python-tk-irc-client.md`

## Scope

- Implement `scripts/irc_tk_client.py` (REQ-001..REQ-006).
- Add unit tests for the parsing helpers (REQ-006).

## Plan (Red → Green → Refactor)

1) RED: Add unit tests for:
   - `.env` parsing (REQ-001)
   - IRC line parsing (prefix/command/params/trailing) (REQ-005)
   - `LIST` numeric parsing (`322`/`323`) (REQ-003)

2) GREEN: Implement minimal helper functions to pass tests.

3) GREEN: Implement a minimal Tk UI:
   - Connect/disconnect
   - Button: LIST channels
   - Join selected channel
   - Text area for messages

4) REFACTOR: Keep GUI code thin; keep protocol parsing in pure functions with tests.

## Verification (Definition of Done)

- Unit tests pass: `python -m unittest -q scripts/test_irc_tk_client.py`
- IO integration test passes: `python -m unittest -q scripts/test_irc_tk_client_integration.py`
- Self-test passes (no network): `python scripts/irc_tk_client.py --self-test`
- Manual sanity (optional, with real server):
  - Connect → LIST → JOIN → see messages

## Risks / Notes

- `LIST` response formats vary by server; only basic RFC-style numerics are supported.
- UTF-8 decoding may vary by server; default is UTF-8 with replacement.
