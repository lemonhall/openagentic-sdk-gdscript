# v4 Plan — Per-NPC Workspace (Shadow Dir)

## Goal

Add a **per-NPC workspace** concept to the Godot addon, inspired by the TypeScript repo’s “shadow workspace”, but simplified for games:

- no “import from real filesystem”
- no “shadow vs real diff/commit”
- just a **strict per-NPC directory** under `user://` that tools can access safely

## Scope

In scope:

- New path helpers in `OAPaths.gd` for:
  - NPC workspace root
  - `SKILL.md` path
- Update session store bootstrap to ensure the workspace directory exists.
- Inject optional `SKILL.md` contents into the system preamble.
- Built-in workspace tools:
  - read/write/list/delete (text-oriented)
  - **path traversal protection** (no `..`, no `user://`, no absolute paths)
- Headless tests for:
  - tool path traversal prevention
  - SKILL preamble injection

Out of scope:

- Shadow-vs-real diff/commit workflows (`/status`, `/commit`)
- Running host-native code inside a sandbox
- Automatic skill compilation/selection

## Acceptance

- Given a `save_id` and `npc_id`, the workspace root resolves to:
  - `user://openagentic/saves/<save_id>/npcs/<npc_id>/workspace/`
- Skills at `workspace/skills/<skill-name>/SKILL.md` are included in agent “system preamble” for that NPC.
- Workspace tools can read/write files inside the workspace and **reject** escaping attempts.

## Files

Create:

- `addons/openagentic/core/OAWorkspaceFs.gd`
- `addons/openagentic/core/OASkills.gd`
- `addons/openagentic/tools/OAStandardTools.gd`
- `addons/openagentic/tools/OAWebTools.gd`
- `tests/addons/openagentic/test_workspace_tools.gd`
- `tests/addons/openagentic/test_skill_preamble.gd`
- `tests/addons/openagentic/test_tool_fs_read_write_edit.gd`
- `tests/addons/openagentic/test_tool_glob_grep.gd`
- `tests/addons/openagentic/test_tool_todowrite.gd`
- `tests/addons/openagentic/test_tool_skill.gd`
- `tests/addons/openagentic/test_tool_webfetch.gd`
- `tests/addons/openagentic/test_tool_websearch.gd`
- `docs/plan/v4-index.md`

Modify:

- `addons/openagentic/core/OAPaths.gd`
- `addons/openagentic/core/OAJsonlNpcSessionStore.gd`
- `addons/openagentic/runtime/OAAgentRuntime.gd`
- `addons/openagentic/OpenAgentic.gd`

## Steps (Tashan / TDD)

1. **Red:** add `test_workspace_tools.gd` asserting escaping paths fail.
2. **Green:** implement `OAWorkspaceFs` path sandboxing + tools.
3. **Red:** add `test_skill_preamble.gd` asserting SKILL content is injected.
4. **Green:** implement SKILL preamble injection and ensure session store creates workspace dir.
5. **Refactor:** keep APIs minimal; avoid adding “commit/import” complexity.

## Risks

- Godot 4.6 strict mode treats warnings as errors → avoid Variant type inference (`:=` on Variant/null).
- Path handling differences across platforms → enforce simple relative-path rules instead of relying on OS path semantics.
