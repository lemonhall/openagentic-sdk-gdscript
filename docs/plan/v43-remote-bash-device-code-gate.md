# v43 — Gate `RemoteBash` Tool Visibility by Desk Device Code

## Goal

`RemoteBash` should only appear when it can realistically work:

- NPC is **desk-bound**
- bound desk has a **valid device code** (paired with a Rust daemon)

This prevents the common failure mode where the tool is visible but the remote daemon will never join the channel, causing long RPC timeouts.

## Scope

In scope:

- Tighten `RemoteBash` availability:
  - require non-empty, valid `device_code` on the bound desk
- Add a fast runtime guard (`DeskNotPaired`) as defense-in-depth
- Update the existing tool visibility test

Out of scope:

- OA1 protocol changes
- Remote daemon changes
- Additional pairing UX

## Acceptance

1) `RemoteBash` is present in tool schemas only when:
   - NPC is bound to a desk, and
   - that desk’s `device_code` is valid (canonical 6–16 chars, `[A-Z0-9]`)
2) If `RemoteBash` is called while not paired, it returns `ERROR: DeskNotPaired` quickly.
3) `tests/projects/vr_offices/test_vr_offices_remote_bash_tool_visibility.gd` covers:
   - unbound → hidden
   - bound + no code → hidden
   - bound + valid code → visible

## Files

Modify:

- `vr_offices/core/agent/VrOfficesRemoteTools.gd`
- `tests/projects/vr_offices/test_vr_offices_remote_bash_tool_visibility.gd`

## Steps (塔山开发循环)

1) **Red**: update the visibility test to expect `RemoteBash` hidden when bound but not paired.
2) **Green**: implement device-code gating in the tool availability + runtime guard.
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_remote_bash_tool_visibility.gd
```

