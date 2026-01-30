# Agent Notes (OpenAgentic Godot)

## 0) Development Discipline (塔山开发循环)

This repo expects **disciplined, test-backed iteration**:

- Use the **塔山开发循环** for any non-trivial change:
  - write/update `docs/plan/vN-*.md` (and `docs/plan/vN-index.md`)
  - execute Red → Green → Refactor with evidence (tests/logs) before claiming “done”
- Keep slices small:
  - one slice → one `git commit` → one `git push`
- If you change behavior, add/adjust tests so the regression can’t ship again.

## 1) Architecture Overview

This repo contains 3 major areas:

1) **OpenAgentic Godot SDK (runtime plugin)**
   - Purpose: provide an agent runtime + tools + session store for Godot games.
   - Key paths:
     - Autoload entry: `addons/openagentic/OpenAgentic.gd`
     - Runtime loop: `addons/openagentic/runtime/OAAgentRuntime.gd`
     - Provider (OpenAI Responses SSE): `addons/openagentic/providers/OAOpenAIResponsesProvider.gd`
     - Tool execution: `addons/openagentic/core/OAToolRunner.gd`, `addons/openagentic/core/OATool.gd`
     - Workspace sandbox FS: `addons/openagentic/core/OAWorkspaceFs.gd`, `addons/openagentic/core/OAPaths.gd`
     - Built-in tools registry: `addons/openagentic/tools/OAStandardTools.gd`

2) **`vr_offices` (3D “game” / orchestrator layer)**
   - Purpose: a real in-engine app that exercises multi-agent orchestration patterns (NPCs, dialogue, hooks, world state).
   - Key paths:
     - Main scene: `vr_offices/VrOffices.tscn`
     - Orchestrator script (keep thin): `vr_offices/VrOffices.gd`
     - Controllers/modules: `vr_offices/core/*.gd`

3) **`demo_rpg` (legacy/simple example)**
   - Purpose: minimal demo; do not expand it in new work unless explicitly asked.

### Data flow (high level)

```
Game UI / NPC logic (vr_offices)
  -> OpenAgentic runtime (OAAgentRuntime)
    -> Provider (OAOpenAIResponsesProvider)
      -> Proxy (optional: /proxy/*)
        -> OpenAI Responses API (SSE streaming)
    <- streamed events/tool calls
  -> ToolRunner -> WorkspaceFs (user:// sandbox) / WebFetch / WebSearch / TodoWrite / Skill ...
  -> SessionStore + world state persisted under user://openagentic/saves/<save_id>/
```

### Persistence layout (important)

- Saves root: `user://openagentic/saves/<save_id>/`
- VR Offices world state: `user://openagentic/saves/<save_id>/vr_offices/state.json`
- NPC private workspace root:
  - `user://openagentic/saves/<save_id>/npcs/<npc_id>/workspace/`
- NPC skills convention:
  - `user://openagentic/saves/<save_id>/npcs/<npc_id>/workspace/skills/<skill-name>/SKILL.md`

## 2) Code Conventions (Negative Knowledge)

Rules that prevent expensive regressions:

- **Architecture hygiene:** keep scripts/modules small and responsibilities single-purpose.
  - If a `.gd` file grows past ~200 LOC (or mixes UI + IO + state + gameplay), pause and self-review: can you split it into smaller focused modules/controllers?
  - Use the “意大利面重构技能” (`skills/spaghetti-refactor/SKILL.md`) to guide safe extraction into modules/controllers.
- **Avoid “god files” in GDScript.** Prefer multiple small scripts over one long one; extract controllers/managers when a script starts accumulating unrelated responsibilities.
- **Godot 4.6 strict mode:** avoid inferred typing from `null`/Variant (`var x := null` will break). Prefer explicit nullable types (`var x: Node = null`) or keep untyped vars.
- **Avoid shadowing built-ins / base members** (`name`, `scale`, `floor`, …). Godot warnings can become errors later.
- **No Bash tool for agents.** Workspace tools must stay inside the NPC private workspace; reject path traversal and absolute/scheme paths.
- **Proxy/Provider schema discipline:** when defining tool JSON schema, arrays must define `items` (Responses API rejects invalid tool schemas).
- **Don’t rely on manual testing for regressions.** If a bug was found by hand (HTTP 400/tool schema/memory leak), add a test so it never ships again.
- **Keep commits small and test-backed.** Prefer “one slice → one commit → push”.
- **Do not touch `demo_rpg/`** unless the task explicitly asks for it (it’s a demo, not the product).
- **Never commit secrets** (API keys, tokens). Use environment variables only.

## 3) Testing Strategy

This repo has two critical “products”, so tests are grouped accordingly:

### A) SDK / OpenAgentic core

- SSE parser & stream plumbing: `tests/test_sse_parser.gd`
- Agent runtime: `tests/test_agent_runtime.gd`
- Session store: `tests/test_session_store.gd`
- Tools: `tests/test_tool_*.gd`

### B) VR Offices orchestration layer

- Scene smoke/persistence/dialogue: `tests/test_vr_offices_*.gd`
- Workspaces (rect zones): `tests/test_vr_offices_workspaces_*.gd`

### C) Demo RPG

- Smoke only: `tests/test_demo_rpg_smoke.gd`

## Running tests (WSL2 + Linux Godot) — recommended

If WSL interop to a Windows `.exe` is flaky (or prompts too much), run tests using a **Linux** Godot binary.

Important: this environment may not allow writing to your real `$HOME`, so set `HOME`/`XDG_*` to a writable temp dir (otherwise Godot may crash when creating `user://`).

Preferred setup: use the pre-extracted Linux Godot binary:

```bash
export GODOT_LINUX_EXE=/home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64
"$GODOT_LINUX_EXE" --version
```

Fallback (extract from zip if you don't have a ready binary):

```bash
mkdir -p /tmp/godot-4.6
unzip -o /home/lemonhall/Godot_v4.6-stable_linux.x86_64.zip -d /tmp/godot-4.6
chmod +x /tmp/godot-4.6/Godot_v4.6-stable_linux.x86_64
/tmp/godot-4.6/Godot_v4.6-stable_linux.x86_64 --version
```

Run the full test suite:

```bash
export GODOT_LINUX_EXE=${GODOT_LINUX_EXE:-/home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64}
export HOME=/tmp/oa-home
export XDG_DATA_HOME=/tmp/oa-xdg-data
export XDG_CONFIG_HOME=/tmp/oa-xdg-config
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

for t in tests/test_*.gd; do
  echo "--- RUN $t"
  timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script "res://$t"
done
```

Run a single test:

```bash
export GODOT_LINUX_EXE=${GODOT_LINUX_EXE:-/home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64}
export HOME=/tmp/oa-home
export XDG_DATA_HOME=/tmp/oa-xdg-data
export XDG_CONFIG_HOME=/tmp/oa-xdg-config
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_sse_parser.gd
```

## Running tests (WSL2 + Windows Godot)

If you are working inside WSL2 but have a Windows Godot executable, use the wrapper script:

```bash
scripts/run_godot_tests.sh
```

Override the executable path if needed:

```bash
GODOT_WIN_EXE="/mnt/e/Godot_v4.6-stable_win64.exe/Godot_v4.6-stable_win64_console.exe" scripts/run_godot_tests.sh
```

Run a single test:

```bash
scripts/run_godot_tests.sh --one tests/test_sse_parser.gd
```

Avoid hung tests (per-test timeout):

```bash
GODOT_TEST_TIMEOUT_SEC=120 scripts/run_godot_tests.sh
```

Notes:
- The script uses `wslpath` to convert Linux paths to Windows paths.
- This runs a Windows `.exe` via WSL interop; some environments may require elevated permissions.

## Running tests (Windows PowerShell)

If WSL interop is flaky, run tests from Windows directly:

```powershell
scripts\\run_godot_tests.ps1
```

Override the executable path if needed:

```powershell
$env:GODOT_WIN_EXE = "E:\\Godot_v4.6-stable_win64.exe\\Godot_v4.6-stable_win64_console.exe"
scripts\\run_godot_tests.ps1
```

Pass extra Godot args (e.g. to debug shutdown leaks):

```powershell
scripts\\run_godot_tests.ps1 -One tests\\test_vr_offices_smoke.gd -ExtraArgs --verbose
```

Avoid hung tests (per-test timeout):

```powershell
$env:GODOT_TEST_TIMEOUT_SEC = "120"
scripts\\run_godot_tests.ps1
```

## VR Offices (3D demo)

Kenney Mini Characters setup:

```bash
scripts/setup_kenney_mini_characters.sh
```

Main scene:

- `res://vr_offices/VrOffices.tscn`

Interaction hint UI (recommended for temporary modes like placement):

- `res://vr_offices/ui/ActionHintOverlay.tscn` (docs: `docs/vr_offices/action_hints.md`)
