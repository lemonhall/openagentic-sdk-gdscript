<!--
  v41 — Desk device-code pairing (UI + persistence + channel naming) + Rust daemon scaffold
-->

# v41 — Desk Device-Code Pairing + Rust Remote Daemon (Scaffold)

## Vision (this version)

- A desk can be **paired** with a remote Rust daemon via a short **device code**:
  - Rust daemon generates a device code (1 per daemon).
  - In-game, the operator right-clicks a desk → chooses “Bind Device Code…” → enters the device code.
  - After validation, the desk **re-derives its IRC channel name** to include both `desk_id` and `device_code`, and **joins quickly**.
- The Rust daemon polls the IRC server channel list every ~30s and joins any channel that matches its device code, completing pairing.
- Pairing is purely transport/config level. OA1 RPC execution on the remote side remains future work.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Desk device code (model + persistence) | `device_code` stored per desk, persisted in `vr_offices/state.json` | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_desk_device_code_persistence.gd` | done |
| M2 | Desk UI (RMB menu + input) | Right-click desk → bind device code UI → applies to that desk | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_desk_overlay_smoke.gd` | done |
| M3 | Desk IRC channel (device code) | DeskIrcLink derives channel including `desk_id` + `device_code` and can switch channels | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_desk_device_code_channel_derivation.gd` | done |
| M4 | Rust daemon scaffold | Device code generation + IRC LIST polling + join matching channels | `cd remote_daemon && cargo test` | done |

## Plan Index

- `docs/plan/v41-desk-device-code-pairing.md`
- `docs/plan/v41-rust-remote-daemon-scaffold.md`

## Evidence

Green:

- `scripts/run_godot_tests.sh --suite vr_offices` (PASS)
- `scripts/run_godot_tests.sh --suite openagentic` (PASS)
- `cd remote_daemon && cargo test` (PASS)
