# v45 — VR Offices: System Prompt Tool List Is Dynamic (RemoteBash-Aware)

## Goal

Fix the root cause of “desk is paired + NPC is desk-bound, but NPC claims RemoteBash doesn’t exist”:

- VR Offices `SYSTEM_PROMPT_ZH` must not hardcode an outdated tool list that excludes `RemoteBash`.
- Instead, it should instruct NPCs to list only tools they can currently see/call, while remaining honest (no invented tools).

## Scope

In scope:

- Update `SYSTEM_PROMPT_ZH` so tool guidance is **dynamic** and includes `RemoteBash` as a desk-bound example.
- Add a regression test proving the prompt won’t regress to the old hardcoded list.

Out of scope:

- RemoteBash availability rules
- Remote daemon / IRC transport

## Acceptance

1) `SYSTEM_PROMPT_ZH` contains `RemoteBash`.
2) `SYSTEM_PROMPT_ZH` does **not** contain the previous hardcoded tool list line:
   `工具：Read / Write / Edit / ListFiles / Mkdir / Glob / Grep / WebFetch / WebSearch / TodoWrite / Skill`
3) Test coverage: `test_vr_offices_system_prompt_remote_bash_mentioned.gd` enforces (1) and (2).

## Files

Modify:

- `vr_offices/core/data/VrOfficesData.gd`

Add:

- `tests/projects/vr_offices/test_vr_offices_system_prompt_remote_bash_mentioned.gd`

## Steps (塔山开发循环)

1) **Red**: add a test that fails if the prompt omits `RemoteBash` or contains the old hardcoded tool list line.
2) **Green**: update the prompt text.
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_system_prompt_remote_bash_mentioned.gd
```

