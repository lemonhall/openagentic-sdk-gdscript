# v91 index

Goal: add channel user listing (`NAMES`) to the Python Tk IRC client.

## Artifacts

- PRD: `docs/prd/2026-02-07-python-tk-irc-client.md` (REQ-007)
- Plan: `docs/plan/v91-python-tk-irc-client-names.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Parse `353/366` numerics and emit `names` event | `python -m unittest -q scripts/test_irc_tk_client.py` | done |
| M2 | Auto-request `NAMES` after JOIN + UI users list | `python -m unittest -q scripts/test_irc_tk_client_integration.py` | done |

## Evidence

- 2026-02-07:
  - `python -m unittest -q scripts/test_irc_tk_client.py` → OK
  - `python -m unittest -q scripts/test_irc_tk_client_integration.py` → OK

