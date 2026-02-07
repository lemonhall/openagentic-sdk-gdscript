# OpenAgentic Godot (GDScript)

[中文](README.zh-CN.md)

![Screenshot](screenshots/screenshot2.png)

Runtime-first **Godot 4** addon that ports the core loop of `openagentic-sdk-ts` into GDScript — plus an IRC demo + multiple in-engine prototypes that exercise real orchestration patterns.

- Event-sourced, per-save + per-NPC **continuous sessions** (JSONL)
- Streaming assistant output (**`assistant.delta`**) via **OpenAI Responses-compatible SSE** (through your own proxy)
- Tool calling loop (**tool registry → permission gate → tool runner**) for driving in-game Actors
- Save-scoped “shadow workspace” under `user://` for NPC/world memory files (no import/commit workflow)

## Screenshots

![VR Offices](screenshots/screenshot.png)

## Video

- YouTube demo: https://www.youtube.com/watch?v=TEJn4F2ivYg

## Status

Early v1 slice: minimal end-to-end core is implemented; API is expected to change.

## What’s included

- **OpenAgentic runtime addon** (`addons/openagentic/`): agent runtime loop + session store + tools + workspace FS sandbox (no Bash tool)
- **VR Offices (3D demo)** (`vr_offices/`): multi-NPC orchestration, installs/teaches skills, persistence, media/IRC integrations
- **IRC demo** (`demo_irc/`): minimal IRC-oriented example project code
- **Local services (optional)**:
  - `proxy/`: tiny dependency-free Node.js SSE proxy for OpenAI Responses API
  - `media_service/`: helper service used by VR Offices media flows
  - `remote_daemon/`: remote tool/daemon experiments used by demos

## Installation

Copy `addons/openagentic/` into your Godot project and enable it by adding an Autoload singleton:

- Autoload name: `OpenAgentic`
- Script: `res://addons/openagentic/OpenAgentic.gd`

## Using from the Godot Asset Library

This repository is a full Godot project.

- If you want **only the addon**, copy `addons/openagentic/` into your own project and add the Autoload.
- If you want the **demos**, open this project and run one of the scenes listed in the “Demo” section.

## Requirements

- Godot **4.x** (this repo is tested on **4.6**)
- If using the built-in local proxy: Node.js 18+

## Persistence layout (per save slot)

Everything is scoped to:

`user://openagentic/saves/<save_id>/`

Per NPC (single continuous “lifetime” session):

- `.../npcs/<npc_id>/session/events.jsonl`
- `.../npcs/<npc_id>/session/meta.json`

Optional memory files injected into the prompt:

- `.../shared/world_summary.txt`
- `.../npcs/<npc_id>/memory/summary.txt`

## Quick start (runtime)

```gdscript
OpenAgentic.set_save_id("slot1")

# Point to your own proxy that speaks OpenAI Responses API (SSE streaming).
OpenAgentic.configure_proxy_openai_responses(
	"https://your-proxy.example/v1",
	"gpt-5.2",
	"authorization",
	"<token>",
	true
)

# Decide tool permissions (v1: allow/deny via callback).
OpenAgentic.set_approver(func(_q: Dictionary, _ctx: Dictionary) -> bool:
	return true
)

# Register tools that the model is allowed to call.
OpenAgentic.register_tool(OATool.new(
	"echo",
	"Echo input",
	func(input: Dictionary, _ctx: Dictionary):
		return input
))

await OpenAgentic.run_npc_turn("npc_blacksmith_001", "Hello", func(ev: Dictionary) -> void:
	# You’ll see assistant.delta/tool.use/tool.result/assistant.message/result events here.
	print(ev)
)
```

## Proxy requirement (SSE)

The client does **not** store a long-lived OpenAI API key. It calls your proxy endpoint:

- `POST /v1/responses` with `stream: true`
- Response is SSE with `data: ...` frames and `[DONE]` terminator

This repo includes a tiny dependency-free Node.js proxy in `proxy/`:

```bash
export OPENAI_API_KEY=...
export OPENAI_BASE_URL=https://api.openai.com/v1  # optional
node proxy/server.mjs
```

## Local dev: start proxy + media + remote daemon

To reduce startup friction, this repo includes a root launcher script and a unified `.env`:

```bash
cp .env.example .env
# edit .env (set OPENAI_API_KEY, OPENAGENTIC_MEDIA_BEARER_TOKEN, etc.)

bash dev-up.sh --no-daemon
```

Windows (PowerShell):

```powershell
Copy-Item .env.example .env
# edit .env (set OPENAI_API_KEY, OPENAGENTIC_MEDIA_BEARER_TOKEN, etc.)

pwsh -NoProfile -File dev-up.ps1 --no-daemon
```

Note: the Rust remote daemon connects to an IRC server (defaults to `127.0.0.1:6667`). If you don’t have one running, use `--no-daemon`.

To run a command with the same environment:

```bash
bash dev-up.sh --no-daemon -- godot4 --path .
```

Windows (PowerShell):

```powershell
pwsh -NoProfile -File dev-up.ps1 --no-daemon godot4 --path .
```

## Tests (local)

This repo includes headless test scripts under `tests/` (requires `godot4` locally):

```bash
godot4 --headless --script tests/addons/openagentic/test_sse_parser.gd
godot4 --headless --script tests/addons/openagentic/test_session_store.gd
godot4 --headless --script tests/addons/openagentic/test_tool_runner.gd
godot4 --headless --script tests/addons/openagentic/test_agent_runtime.gd
```

WSL2 + Windows Godot helper script:

```bash
scripts/run_godot_tests.sh
scripts/run_godot_tests.sh --suite openagentic
scripts/run_godot_tests.sh --suite vr_offices
```

WSL2 + Linux Godot (recommended):

If you have a Linux Godot 4.6 binary available, you can run all tests without WSL interop.
In some sandboxed setups, Godot may not be able to write to your real `$HOME`, so point `HOME`/`XDG_*` to a writable temp dir (otherwise `user://` init can crash).

```bash
export HOME=/tmp/oa-home
export XDG_DATA_HOME=/tmp/oa-xdg-data
export XDG_CONFIG_HOME=/tmp/oa-xdg-config
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

while IFS= read -r t; do
  echo "--- RUN $t"
  /tmp/godot-4.6/Godot_v4.6-stable_linux.x86_64 --headless --rendering-driver dummy --path "$(pwd)" --script "res://$t"
done < <(find tests -type f -name 'test_*.gd' | LC_ALL=C sort)
```

## Demo (talk to the first NPC)

1. Start the proxy (above).
2. Run the Godot project.
   - Default main scene is the 3D VR Offices demo: `res://vr_offices/VrOffices.tscn`
   - The IRC demo scene: `res://demo_irc/Main.tscn`
   - The RPG-style demo remains at: `res://demo_rpg/World.tscn`
   - The older “chat UI” demo remains at `res://demo/Main.tscn`

## VR Offices (3D demo)

A separate 3D “office sim” prototype lives under `vr_offices/`.

1. Extract assets (Kenney Mini Characters 1):

```bash
scripts/setup_kenney_mini_characters.sh
```

2. Open and run: `res://vr_offices/VrOffices.tscn`

Controls:

- Orbit: hold **Right Mouse** and drag
- Zoom: mouse wheel
- Add/remove NPC: UI panel (click NPC to select)

## Assets

The RPG demo uses Kenney CC0 art. If you didn't clone with assets already present, you can import them from a local zip:

```bash
scripts/import_kenney_roguelike_rpg_pack.sh
scripts/import_kenney_roguelike_characters.sh
```

See `assets/CREDITS.md`.

## Collision masks (auto draft)

For “painted background” maps, collisions can be generated from a PNG mask (opaque = obstacle). This repo includes:

- Generator: `python3 scripts/generate_collision_mask.py <background.png> --out <mask.png>`
- Runtime collider: `demo_rpg/collision/OACollisionFromMask.gd`

Details: `docs/collision_masks/README.md`

Optional environment variables for the demo:

- `OPENAGENTIC_PROXY_BASE_URL` (default `http://127.0.0.1:8787/v1`)
- `OPENAGENTIC_MODEL` (default `gpt-5.2`)
- `OPENAGENTIC_SAVE_ID` (default `slot1`)
- `OPENAGENTIC_NPC_ID` (default `npc_1`)

## Docs / Plans

- `docs/plan/v1-index.md`
- `docs/plan/v2-index.md`
- `docs/plan/v2-rpg-demo.md`
- `docs/plan/v3-index.md`
- `docs/plan/v3-vr-offices.md`
- `docs/plans/2026-01-28-openagentic-godot4-runtime.md`

## License

Code in this repository is licensed under **Apache-2.0** (see `LICENSE`).

Third-party assets may have their own licenses:

- Kenney art under `assets/kenney/` is **CC0** (see `assets/CREDITS.md` and `assets/kenney/**/License.txt`).
