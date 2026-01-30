# v2 Plan — RPG Demo Scene + Dialogue UI

## Goal

Create a small **top-down 2D RPG demo** scene in Godot 4 that uses the existing `OpenAgentic` runtime to drive NPC dialogue with **SSE streaming**.

## Scope

In scope:

- A new `demo_rpg/` playable scene with:
  - Player movement (WASD/arrow keys) + collisions
  - At least one NPC with a stable `npc_id`
  - Proximity interaction prompt + `E` to talk
  - Bottom dialogue UI (NPC name, streamed text, player input)
- Kenney CC0 assets added into the repo with minimal attribution docs
- A headless smoke test that loads the scene and verifies required nodes/scripts exist

Out of scope (v2):

- Combat, inventory, quests
- Procedural NPC spawning systems
- Automatic memory compacting/summarization policies

## Acceptance

- Running the project in Godot (GUI):
  - Player can move around.
  - When near the NPC, the prompt appears.
  - Pressing `E` opens the dialogue UI.
  - Sending text streams the NPC response into the dialogue UI.
  - Pressing ESC (or a close button) exits talk mode and returns to movement.
- Sessions continue to persist under `user://openagentic/saves/<save_id>/...` and are per-NPC continuous.
- `tests/projects/demo_rpg/test_demo_rpg_smoke.gd` passes headless.

## Files

Create (planned):

- `demo_rpg/World.tscn`
- `demo_rpg/World.gd`
- `demo_rpg/player/Player.tscn`
- `demo_rpg/player/PlayerController.gd`
- `demo_rpg/npcs/Npc.tscn`
- `demo_rpg/npcs/OAInteractableNpc.gd`
- `demo_rpg/ui/DialogueBox.tscn`
- `demo_rpg/ui/OADialogueBox.gd`
- `demo_rpg/ui/InteractPrompt.tscn`
- `demo_rpg/ui/InteractPrompt.gd`
- `tests/projects/demo_rpg/test_demo_rpg_smoke.gd`

Assets (planned):

- `assets/kenney/...` (tiles + characters; CC0)
- `assets/kenney/CREDITS.md` (or `assets/CREDITS.md`)

Modify (planned):

- `project.godot` (optionally switch `run/main_scene` to `res://demo_rpg/World.tscn` when ready)
- `README.md` and `README.zh-CN.md` (add v2 demo note)
- `docs/plan/v1-index.md` (add link to v2 index)

## Steps (Tashan loop)

### Slice 1 — Scene skeleton + smoke test

1) **RED**: Add `tests/projects/demo_rpg/test_demo_rpg_smoke.gd` that:
   - loads `res://demo_rpg/World.tscn`
   - asserts required child nodes exist (`Player`, at least one `Npc`, UI nodes)
   - exits non-zero if anything is missing

2) **GREEN**: Create the minimal `demo_rpg/World.tscn` with placeholder nodes + scripts so the smoke test passes.

3) **Verify**:
   - `godot4 --headless --script tests/projects/demo_rpg/test_demo_rpg_smoke.gd`

4) **Commit**:
   - `git commit -m "v2: add RPG demo scene skeleton"`

### Slice 2 — Player movement + interaction prompt

1) **RED**: Extend the smoke test (or add a new test) to assert:
   - `PlayerController.gd` exists and is attached
   - NPC node has an `Area2D` (interaction range)

2) **GREEN**:
   - Implement `PlayerController.gd` (top-down movement with `CharacterBody2D`)
   - Implement `OAInteractableNpc.gd`:
     - exported `npc_id` (String), `display_name` (String)
     - an `Area2D` used for proximity detection
   - Implement `InteractPrompt.gd`:
     - shows/hides based on nearest interactable NPC
     - `E` triggers `World` to enter talk mode

3) **Verify (manual)**:
   - Run Godot GUI, move to NPC, see prompt toggle.

4) **Commit**:
   - `git commit -m "v2: add player movement and NPC interaction prompt"`

### Slice 3 — Dialogue UI + OpenAgentic streaming integration

1) **RED**: Add a minimal headless test that can instantiate `OADialogueBox.gd` and:
   - call `open(npc_id, display_name)`
   - call `append_assistant_delta("...")`
   - verify internal text buffer matches expected

2) **GREEN**:
   - `OADialogueBox.gd`:
     - bottom panel UI with speaker name + streamed output label
     - player input line + send button
     - handles busy state while streaming
   - `World.gd` wires:
     - `OpenAgentic.set_save_id(...)` (use a v2 demo default like `slot1`)
     - `OpenAgentic.run_npc_turn(npc_id, text, on_event)`
     - streams `assistant.delta` into `OADialogueBox`

3) **Verify (manual)**:
   - Start proxy and talk to NPC; confirm streaming output.

4) **Commit**:
   - `git commit -m "v2: add dialogue UI with streaming NPC chat"`

### Slice 4 — Kenney CC0 assets

1) Add CC0 assets under `assets/kenney/` and record attribution in `assets/kenney/CREDITS.md`.
2) Update scenes to use the sprites/tiles instead of placeholders.
3) Verify manually: scene looks like a classic 2D RPG.
4) Commit: `git commit -m "v2: add Kenney CC0 art and hook up sprites"`

### Slice 5 — Switch main scene (optional)

When the RPG demo is stable, set `run/main_scene` to `res://demo_rpg/World.tscn`.

## Risks

- Godot input focus conflicts between “movement” and “text input”: mitigate via explicit state machine (walk vs talk).
- Headless testing UI-heavy scenes can be brittle: keep tests as smoke/unit tests for scripts, rely on manual verification for visuals.

