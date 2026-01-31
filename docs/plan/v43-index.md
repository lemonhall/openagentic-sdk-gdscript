<!--
  v43 — RemoteBash tool visibility requires desk pairing (device code)
-->

# v43 — RemoteBash Requires Desk Device-Code Pairing

## Vision (this version)

- Reduce accidental timeouts and operator confusion:
  - `RemoteBash` is visible **only** when the NPC is desk-bound **and** the bound desk has a **valid device code**.
- Keep a runtime safety net:
  - If `RemoteBash` is somehow called without pairing, return a fast, clear error (`DeskNotPaired`) instead of waiting for RPC timeouts.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Tool visibility gating | `RemoteBash` requires valid desk `device_code` | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_remote_bash_tool_visibility.gd` | done |

## Plan Index

- `docs/plan/v43-remote-bash-device-code-gate.md`

## Evidence

Green:

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_remote_bash_tool_visibility.gd` (PASS)
- `scripts/run_godot_tests.sh --suite vr_offices` (PASS)
