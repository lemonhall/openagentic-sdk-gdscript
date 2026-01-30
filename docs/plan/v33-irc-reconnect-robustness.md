# v33 — IRC Reconnect Robustness

## Goal

Fix “desks connect slowly / stuck connecting / reconnect stops after ERROR” by hardening IRC auto-reconnect in the core client:

- Reconnect even when the first connect attempt fails before ever becoming “connected”.
- Reconnect after server-sent `ERROR` lines (don’t classify them as user-initiated closes).

## Scope

In scope:

- `IrcClientCoreEngine` reconnect behavior for pre-connected failures (`STATUS_ERROR/STATUS_NONE` while `_was_connected == false`).
- Remote close path for inbound server `ERROR`.
- Tests covering both cases.

Out of scope:

- Changing VR Offices desk/link logic or UI.
- Changing ngIRCd server configuration (limits, TLS, etc).

## Acceptance

- With auto-reconnect enabled, a failed initial connect attempt triggers reconnect attempts using the existing backoff policy.
- With auto-reconnect enabled, receiving `ERROR ...` from the server triggers a reconnect attempt.
- Existing reconnect + rejoin behavior continues to work.
- Tests pass.

## Files

- `addons/irc_client/IrcClientCoreEngine.gd`
- `tests/addons/irc_client/test_irc_reconnect_initial_connect_failure.gd`
- `tests/addons/irc_client/test_irc_reconnect_after_server_error.gd`

## Steps (塔山开发循环)

### 1) Red

- Add failing tests for:
  - initial connect failure (never reaches `STATUS_CONNECTED`)
  - server `ERROR` disconnect

### 2) Green

- Update `IrcClientCoreEngine` to:
  - schedule reconnect on `STATUS_ERROR/STATUS_NONE` even if never connected
  - treat inbound server `ERROR` closes as remote disconnects (reconnect eligible)

### 3) Review

Run:

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/addons/irc_client/test_irc_reconnect_initial_connect_failure.gd
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/addons/irc_client/test_irc_reconnect_after_server_error.gd
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/addons/irc_client/test_irc_reconnect_rejoin.gd
```

