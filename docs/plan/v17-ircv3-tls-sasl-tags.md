# v17 Plan — IRC Client Plugin (TLS + IRCv3 CAP/SASL/Tags)

## Goal

Extend the v16 IRC client addon to support TLS and the minimal IRCv3 feature set needed for capability negotiation, standardized login, and metadata tags.

## Scope (v17)

- TLS transport (`StreamPeerTLS`) option.
- IRCv3 capability negotiation:
  - Discover server capabilities.
  - Request a configured subset.
  - Enter “normal registration” after CAP ends.
- SASL authentication (client credentials via config, no secrets in repo).
- Message tags:
  - Parse tags into `IrcMessage.tags: Dictionary[String, String]`.
  - Tags without `=` store as empty string (`""`).
  - Unescape tag values per IRCv3 (at minimum): `\\:`→`;`, `\\s`→` `, `\\r`→CR, `\\n`→LF, `\\\\`→`\\`.
  - (Roundtrip formatting can be a later slice; v17 first slice is parse + tests.)

## Non-Goals (v17)

- Full IRCv3 ecosystem (batch, labeled-response, message-ids, etc.) unless explicitly added as a later slice.
- Multi-server manager and reconnection UX (v18).

## Acceptance (high-level)

- Tests cover:
  - Tags parsing (`@a=b;c;d= :prefix CMD ...`) edge-cases.
  - CAP flow state machine (unit tests with scripted server messages).
  - SASL flow happy-path (unit tests with scripted server messages).
- TLS code path is exercised by tests (integration preferred; unit-level acceptable if integration is too brittle).

## Steps (塔山开发循环)

- Slice 1 (Tags):
  - **Red:** add `tests/addons/irc_client/test_irc_parser_tags.gd`.
  - **Green:** extend `addons/irc_client/IrcMessage.gd` + `addons/irc_client/IrcParser.gd` to parse tags.
  - **Verify:** run `tests/addons/irc_client/test_irc_parser.gd` and `tests/addons/irc_client/test_irc_parser_tags.gd` headless.

- Slice 2 (CAP):
  - **Red:** unit tests for CAP state transitions.
  - **Green:** implement minimal CAP flow.

- Slice 3 (SASL):
  - **Red:** unit tests for SASL PLAIN happy-path.
  - **Green:** implement minimal SASL PLAIN flow.
  - Evidence: `tests/addons/irc_client/test_irc_client_sasl_plain.gd`.

- Slice 4 (TLS):
  - Prefer integration tests where environment permits; otherwise isolate transport wiring and cover API branches.
  - Evidence: `tests/addons/irc_client/test_irc_tls_api.gd`.
