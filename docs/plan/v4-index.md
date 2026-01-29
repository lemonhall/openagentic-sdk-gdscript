# v4 Index — Per-NPC Workspace (Shadow Dir)

## Vision (v4)

Port the **shadow workspace isolation** idea from `openagentic-sdk-ts` into the Godot runtime addon, but tailored for games:

- Each save slot has many NPCs; **each NPC gets its own private workspace directory**.
- OpenAgentic built-in tools may only access that workspace directory (no `res://`, no arbitrary `user://`).
- Each NPC workspace can contain skills under `workspace/skills/<skill-name>/SKILL.md` to give the NPC differentiated behavior.
- Provide a standard tool suite (no Bash): `Read`, `Write`, `Edit`, `Glob`, `Grep`, `WebFetch`, `WebSearch` (Tavily), `TodoWrite`, `Skill`.

## Milestones (facts panel)

1. **Paths:** define per-NPC workspace paths under `user://openagentic/saves/<save_id>/npcs/<npc_id>/workspace/`. (done)
2. **Skill preamble:** load optional `workspace/skills/*/SKILL.md` into the system preamble for that NPC. (done)
3. **Workspace tools:** add safe tool suite constrained to the workspace root (no Bash). (done)
4. **Tests:** add headless tests for path traversal prevention + SKILL preamble injection. (doing)

## Current status (Jan 29, 2026)

- Workspace FS sandbox + skills loader + standard tool suite implemented.
- Waiting on Windows test run confirmation that `test_skill_preamble.gd` and the new tool tests are green.

## Plans (v4)

- `docs/plan/v4-npc-workspace.md`

## Definition of Done (DoD)

- For a given `save_id` + `npc_id`, OpenAgentic can:
  - create/ensure the NPC workspace directory
  - read optional `SKILL.md` and include it in the system preamble
  - run built-in workspace file tools that cannot escape the workspace root
- Tests exist and pass under `tests/`.

## Verification (local)

Windows PowerShell:

- `scripts\\run_godot_tests.ps1 -One tests\\test_workspace_tools.gd`
- `scripts\\run_godot_tests.ps1 -One tests\\test_skill_preamble.gd`
- `scripts\\run_godot_tests.ps1 -One tests\\test_tool_fs_read_write_edit.gd`
- `scripts\\run_godot_tests.ps1 -One tests\\test_tool_glob_grep.gd`
- `scripts\\run_godot_tests.ps1 -One tests\\test_tool_todowrite.gd`
- `scripts\\run_godot_tests.ps1 -One tests\\test_tool_skill.gd`
- `scripts\\run_godot_tests.ps1 -One tests\\test_tool_webfetch.gd`
- `scripts\\run_godot_tests.ps1 -One tests\\test_tool_websearch.gd`
