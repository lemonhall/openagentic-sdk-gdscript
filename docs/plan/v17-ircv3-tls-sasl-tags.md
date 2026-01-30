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
  - Parse tags into a dictionary on the message.
  - Preserve tags for roundtrip formatting (when sending).

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

- Write failing tests first for tags + CAP + SASL.
- Implement minimal functionality to pass.
- Refactor into small scripts if files approach ~200 LOC.

