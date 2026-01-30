# v18 Plan — IRC Client Auto Reconnect + Deterministic Rejoin

## Goal

When the IRC connection drops unexpectedly, the client must automatically reconnect with a deterministic backoff and restore the session:

- re-register (PASS/NICK/USER sequence as configured)
- re-join previously joined channels (after welcome)

## Scope

- Deterministic backoff (no jitter) and deterministic rejoin sequencing (no “sleep” or real network dependency in tests).
- Works without real sockets in tests (peer factory).
- Join list is driven by `join()` / `part()` calls and re-joined after numeric `001`.

Out of scope (deferred in v18):

- Full multi-server/channel/user/topic state tracking
- CTCP VERSION/PING (ACTION already exists)
- Local history persistence

## Acceptance

- A forced disconnect triggers a reconnect attempt after configured backoff.
- Reconnect triggers a re-register (NICK/USER at minimum) deterministically.
- Re-join happens only after `001` and is deterministic in tests.

## Files

- `addons/irc_client/IrcClientTransport.gd`
- `addons/irc_client/IrcClientReconnect.gd`
- `addons/irc_client/IrcClientChannels.gd`
- `addons/irc_client/IrcClientInbound.gd`
- `addons/irc_client/IrcClientCore.gd`
- `addons/irc_client/IrcClientCoreEngine.gd`
- `addons/irc_client/IrcClientCoreCommands.gd`
- `addons/irc_client/IrcClient.gd`
- `tests/addons/irc_client/test_irc_reconnect_rejoin.gd`

## Steps (塔山开发循环)

1) **Red:** add `tests/addons/irc_client/test_irc_reconnect_rejoin.gd` that expects:
   - peer-factory based connect
   - forced disconnect
   - delayed reconnect
   - re-register on reconnect
   - re-join after `001`
2) **Green:** implement:
   - `set_peer_factory`, `set_auto_reconnect_enabled`, `set_reconnect_backoff_seconds`, `set_auto_rejoin_enabled`
   - reconnect scheduler + channel rejoin tracker
3) **Refactor:** split `IrcClient` internals to keep files small (~200 LOC self-review trigger) while keeping tests green.

