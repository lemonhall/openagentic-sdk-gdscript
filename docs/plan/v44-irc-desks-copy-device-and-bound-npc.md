# v44 — IRC Desks: Copy Diagnostics Includes Device Code + Bound NPC

## Goal

When debugging desks (pairing, join status, tool availability), the operator should be able to copy a single block of diagnostics that includes:

- `device_code` (the machine pairing code bound to the desk)
- the NPC currently bound to the desk (id + display name)

## Scope

In scope:

- Extend desk IRC “snapshot” data to include:
  - `device_code`
  - `bound_npc_id`, `bound_npc_name`
- Show these fields in the Desks panel info area (and thus the Copy button output).
- Add/extend tests so the presence of these fields is covered.

Out of scope:

- Any changes to RemoteBash tool availability rules
- Remote daemon behavior
- Persisting bound NPC fields (they are runtime-only)

## Acceptance

1) In `IrcOverlay` → `Desks` tab, selecting a desk shows diagnostics containing lines:
   - `device_code=<...>`
   - `bound_npc_id=<...>`
   - `bound_npc_name=<...>`
2) Clicking “Copy” copies the same diagnostics block (including those lines).
3) The existing UI smoke test covers the new fields.

## Files

Modify:

- `vr_offices/core/desks/VrOfficesDeskIrcSnapshots.gd`
- `vr_offices/furniture/DeskNpcBindIndicator.gd`
- `vr_offices/ui/IrcOverlay.gd`
- `tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_copy_smoke.gd`

Add:

- `vr_offices/core/desks/VrOfficesDeskIrcSnapshots.gd.uid`

## Steps (塔山开发循环)

1) **Red**: update `test_vr_offices_irc_overlay_desks_copy_smoke.gd` to assert the copied diagnostics includes `device_code` + bound NPC fields.
2) **Green**: implement snapshot + UI changes; expose `get_bound_npc_name()` from `DeskNpcBindIndicator`.
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_irc_overlay_desks_copy_smoke.gd
```

