# v17 Index — IRC Client Plugin (TLS + IRCv3 Basics)

## Vision (v17)

Build on v16 by adding modern interoperability features commonly expected in “real” IRC usage:

- TLS encrypted connections.
- IRCv3 capability negotiation (`CAP`) so the client can opt into supported extensions.
- SASL authentication (so login is standardized instead of relying on ad-hoc `NickServ` messages).
- Message tags parsing/preservation (metadata on messages).

## Milestones (facts panel)

1. **Plan:** write an executable v17 plan with tests. (todo)
2. **TLS:** `StreamPeerTLS` support + tests. (todo)
3. **CAP:** capability negotiation flow + tests. (done)
4. **SASL:** auth flow + tests. (todo)
5. **Tags:** parse message tags + tests. (done)

## Plans (v17)

- `docs/plan/v17-ircv3-tls-sasl-tags.md`

## Definition of Done (DoD)

- Client can connect to a TLS endpoint (test via local TLS harness or focused unit tests if integration is hard).
- Client can perform CAP negotiation and SASL auth (where server supports it).
- Parser supports message tags and preserves them in the parsed message structure.

## Evidence

- Tests:
  - `tests/test_irc_parser_tags.gd`
  - `tests/test_irc_client_cap.gd`
