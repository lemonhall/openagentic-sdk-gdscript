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

## Run

Open and run:

- `res://vr_offices/VrOffices.tscn`

Controls:

- Orbit: hold **Right Mouse** and drag
- Zoom: mouse wheel
- Pan: hold **Middle Mouse** and drag
- Add/remove NPC: UI panel (click NPC to select)

