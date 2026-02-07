# v91: Python Tk IRC client (NAMES user list)

PRD trace: `docs/prd/2026-02-07-python-tk-irc-client.md` (REQ-007)

## Scope

- Add `NAMES` user listing for a joined/selected channel.

## Plan (Red → Green → Refactor)

1) RED: Unit test for parsing `353` numeric lines into `(channel, names[])`.
2) GREEN: Implement `parse_names_numeric()` and normalize common nick prefixes (`~&@%+`).
3) RED: Integration test: after `JOIN #chan1`, the client sends `NAMES #chan1` and surfaces a `names` event when `366` arrives.
4) GREEN: Implement buffering + emit `names` event on `366`.
5) GREEN: UI adds a Users list panel and a `NAMES (selected)` refresh button; auto-requests `NAMES` on join.

## Verification (Definition of Done)

- `python -m unittest -q scripts/test_irc_tk_client.py`
- `python -m unittest -q scripts/test_irc_tk_client_integration.py`

