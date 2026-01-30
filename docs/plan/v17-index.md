# v17 Index — IRC Client Plugin (TLS + IRCv3 Basics)

## Vision (v17)

Build on v16 by adding modern interoperability features commonly expected in “real” IRC usage:

- TLS encrypted connections.
- IRCv3 capability negotiation (`CAP`) so the client can opt into supported extensions.
- SASL authentication (so login is standardized instead of relying on ad-hoc `NickServ` messages).
- Message tags parsing/preservation (metadata on messages).

Note: “IRCv3 完整实现”在工程上需要收敛为可验收的 Profile；见 `docs/plan/v17-ircv3-completeness-profile.md`。

## Milestones (facts panel)

1. **Plan:** write an executable v17 plan with tests. (done)
2. **TLS:** `StreamPeerTLS` support + tests. (done)
3. **CAP:** capability negotiation flow + tests. (done)
4. **SASL:** auth flow + tests. (done)
5. **Tags:** parse message tags + tests. (done)
6. **Hardening:** CAP multiline/value caps + SASL chunking + tests. (done)
7. **Coverage:** expand v17 test diversity + CAP param-list support. (done)
8. **IRCv3 Profile A:** define “complete” + CAP LIST/NEW/DEL + tests. (done)

## Plans (v17)

- `docs/plan/v17-ircv3-tls-sasl-tags.md`
- `docs/plan/v17-ircv3-cap-sasl-hardening.md`
- `docs/plan/v17-ircv3-test-diversity-2.md`
- `docs/plan/v17-ircv3-completeness-profile.md`

## Definition of Done (DoD)

- Client can connect to a TLS endpoint (test via local TLS harness or focused unit tests if integration is hard).
- Client can perform CAP negotiation and SASL auth (where server supports it).
- Parser supports message tags and preserves them in the parsed message structure.

## Evidence

- Tests:
  - `tests/test_irc_parser_tags.gd`
  - `tests/test_irc_parser_tags_escapes.gd`
  - `tests/test_irc_cap_negotiation_list_new_del.gd`
  - `tests/test_irc_client_cap.gd`
  - `tests/test_irc_client_cap_disabled_registers.gd`
  - `tests/test_irc_client_cap_ls_without_trailing_colon.gd`
  - `tests/test_irc_client_cap_multiline_and_values.gd`
  - `tests/test_irc_client_cap_nak_still_registers.gd`
  - `tests/test_irc_client_sasl_plain.gd`
  - `tests/test_irc_client_sasl_plain_chunking.gd`
  - `tests/test_irc_client_sasl_failure_ends_cap.gd`
  - `tests/test_irc_tls_api.gd`
