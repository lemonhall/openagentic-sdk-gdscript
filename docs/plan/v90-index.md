# v90 index

Goal: provide a simple Python Tk IRC client that reads `.env` and can LIST/JOIN/show messages.

## Artifacts

- PRD: `docs/prd/2026-02-07-python-tk-irc-client.md`
- Plan: `docs/plan/v90-python-tk-irc-client.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Unit tests for config + line/LIST parsing | `python -m unittest -q scripts/test_irc_tk_client.py` | done |
| M2 | IO integration (PING/PONG + LIST + JOIN + PRIVMSG) | `python -m unittest -q scripts/test_irc_tk_client_integration.py` | done |
| M3 | CLI usage + no-network self-test | `python scripts/irc_tk_client.py --self-test` | done |

## Evidence

- 2026-02-07:
  - `python -m unittest -q scripts/test_irc_tk_client.py` → OK
  - `python -m unittest -q scripts/test_irc_tk_client_integration.py` → OK
  - `python scripts/irc_tk_client.py --self-test` → OK
  - `python scripts/irc_tk_client.py --help` → OK

