<!--
  v47 — IRC Desks: Desk copy diagnostics includes computed RemoteBash should-be visibility
-->

# v47 — IRC Desks: Copy Diagnostics Includes RemoteBash Should-Be

## Vision (this version)

- Make multi-desk tool debugging faster:
  - Desk diagnostics (the part you Copy) includes a computed line:
    - `remote_bash_visible_should_be=true/false`
- Keep expectations explicit:
  - The computation follows current desk-bound tool visibility rules (v43):
    - RemoteBash should be visible if and only if the desk is bound to an NPC and the desk has a valid paired `device_code`.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Desk diagnostics copy | Desks panel copy text includes `remote_bash_visible_should_be=<true/false>` (computed) | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_copy_smoke.gd` | done |

## Plan Index

- `docs/plan/v47-irc-desks-copy-remote-bash-visible-should-be.md`

## Evidence

Green:

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_copy_smoke.gd` (PASS)
- Note: `scripts/run_godot_tests.sh --suite vr_offices` currently fails in this workspace due to ongoing v46 work (unrelated to v47).
