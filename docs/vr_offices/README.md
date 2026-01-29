# VR Offices (v3)

`vr_offices/` is a 3D prototype scene for an “office sim” style game:

- The player is a **camera** (orbit + zoom), not a controllable character.
- NPCs are **3D characters** (Kenney Mini Characters 1).
- You can add/remove NPCs via UI and click to select an NPC.

## Assets

Download Kenney “Mini Characters 1” and place the zip at the repo root as:

- `kenney_mini-characters.zip`

Then extract the minimal set of GLBs this demo uses:

```bash
scripts/setup_kenney_mini_characters.sh
```

Extracted files live under:

- `assets/kenney/mini-characters-1/`

Texture note:

- The characters use a shared atlas: `assets/kenney/mini-characters-1/Textures/colormap.png`
- If your NPCs show up as “white untextured”, use Godot’s **Reimport** on the folder after running the setup script.

Animation note:

- Kenney Mini Characters 1 includes **embedded animations** in the model files.
- If you see a T-pose, it usually means the imported `AnimationPlayer` exists but nothing is playing; this demo auto-plays an `idle` animation when present.
- Full list: `docs/vr_offices/animations.md`

### Animation list (Kenney Mini Characters 1)

These are the **32** embedded animation names found in `character-male-a.glb`:

- `static`
- `idle`
- `walk`
- `sprint`
- `jump`
- `fall`
- `crouch`
- `sit`
- `drive`
- `die`
- `pick-up`
- `emote-yes`
- `emote-no`
- `holding-right`
- `holding-left`
- `holding-both`
- `holding-right-shoot`
- `holding-left-shoot`
- `holding-both-shoot`
- `attack-melee-right`
- `attack-melee-left`
- `attack-kick-right`
- `attack-kick-left`
- `interact-right`
- `interact-left`
- `wheelchair-sit`
- `wheelchair-look-left`
- `wheelchair-look-right`
- `wheelchair-move-forward`
- `wheelchair-move-back`
- `wheelchair-move-left`
- `wheelchair-move-right`

To list animations without Godot (reads the `.glb` JSON chunk):

```bash
scripts/list_glb_animations.py assets/kenney/mini-characters-1/character-male-a.glb
```

## Run

Open and run:

- `res://vr_offices/VrOffices.tscn`

Controls:

- Orbit: hold **Right Mouse** and drag
- Zoom: mouse wheel
- Pan: hold **Middle Mouse** and drag
- Add/remove NPC: UI panel (click NPC to select)
- Talk: select an NPC, press **E** to open a modern chat overlay (Esc to close)

## BGM

The scene includes a looping background track:

- `assets/audio/pixel_coffee_break.mp3`

## NPC wandering

NPCs do a light random walk inside the spawn rectangle (so they won’t walk off the floor):

- Bounds are derived from `VrOffices.gd` `spawn_extent` and set on each NPC via `wander_bounds`.
- The NPC script switches between `idle` and `walk` animations based on whether it’s moving.
- If the character appears to “walk backwards”, tweak `Npc.gd` `model_yaw_offset` (Kenney Mini Characters default is `PI`).
- If the character starts “sliding” after a few seconds, it usually means `walk` wasn’t looping; this demo forces `idle`/`walk` to loop at runtime.
- Selected NPCs show a Sims-style “plumbob” above the head; its size/height are configurable in `Npc.tscn` and the bobbing amount is in `Npc.gd`.

## NPC rules (unique profiles + names)

This demo enforces simple rules when adding NPCs:

- The Kenney pack provides **12** character models in this demo, so you can have at most **12 NPCs** at once.
- Each NPC uses a **unique** `.glb` (no duplicates while all 12 are present).
- Each `.glb` is mapped to a fixed **display name** based on the selected culture (default: `zh-CN`).

Culture selection:

- Use the UI dropdown to switch between `zh-CN`, `en-US`, and `ja-JP`.
- Switching culture updates existing NPC display names.

## Dialogue (OpenAgentic)

This scene reuses the same OpenAgentic runtime (streaming SSE) as the other demos, but with a more modern overlay UI.

Defaults (override via env vars):

- `OPENAGENTIC_PROXY_BASE_URL` (default `http://127.0.0.1:8787/v1`)
- `OPENAGENTIC_MODEL` (default `gpt-5.2`)
- `OPENAGENTIC_SAVE_ID` (default `slot1`)
