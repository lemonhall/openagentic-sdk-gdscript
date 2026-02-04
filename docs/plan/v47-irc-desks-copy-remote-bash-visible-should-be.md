# v47 — IRC Desks: Copy Diagnostics Includes RemoteBash Should-Be

## Goal

When debugging desks (pairing, binding, tool availability), the operator should be able to copy a single block of diagnostics that includes:

- `remote_bash_visible_should_be=<true/false>` computed from the current desk snapshot

This lets us quickly distinguish:

- “RemoteBash should be available but isn’t” (bug / prompt / tool registry / binding drift)
- “RemoteBash should not be available” (unbound or unpaired desk)

## Scope

In scope:

- Add a computed diagnostics line to the Desks panel info area (and thus the Copy button output):
  - `remote_bash_visible_should_be=<true/false>`
- Computation uses the same rule as RemoteBash availability (v43):
  - bound NPC exists (`bound_npc_id` non-empty)
  - paired desk exists (valid canonical `device_code`)
- Add/extend tests so the presence of this line is covered.

Out of scope:

- Any changes to RemoteBash tool availability rules
- Remote daemon behavior
- Any changes to desk binding mechanics

## Acceptance

1) In `SettingsOverlay` → `Desks` tab, selecting a desk shows diagnostics containing the line:
   - `remote_bash_visible_should_be=<true/false>`
2) Clicking “Copy” copies the same diagnostics block (including that line).
3) The existing UI smoke test covers the new line.

## Files

Modify:

- `vr_offices/ui/SettingsOverlay.gd`
- `tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_copy_smoke.gd`

## Steps (塔山开发循环)

1) **Red**: update `test_vr_offices_irc_overlay_desks_copy_smoke.gd` to assert the copied diagnostics includes `remote_bash_visible_should_be=true`.
2) **Green**: compute the should-be flag in `SettingsOverlay._on_desk_selected` using `VrOfficesIrcNames` device code canonicalization + validation.
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_copy_smoke.gd
```
