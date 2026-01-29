# v3 Index — VR Offices (Godot 4, 3D)

## Vision (v3)

Create a new 3D “game” under `vr_offices/` that feels like a **tiny office sim**:

- No “Player character” — the player is a **god-view camera** that can look around the office.
- The world is a normal 3D scene with **gravity**, **ground collision**, and **indoor lighting**.
- You can **add NPCs** into the office and **remove NPCs** via UI.
- You can **mouse-click to select** an NPC (keyboard selection can be added later).
- NPC visuals come from Kenney “Mini Characters 1” (GLB). (`kenney_mini-characters.zip`)

Non-goals (v3):

- No agent dialogue or OA tool loop integration in this version.
- No full office interior modeling; a simple floor + light is enough.

## Milestones (facts panel)

Milestone 1 tag:

- `v3-m1` (`d8c5a5994f2ace9ea6ddb934c70b4caf6d99aece`)

1. **Scene baseline:** 3D world with floor, gravity, light, orbit camera. (done)
2. **NPC spawn/remove UI:** Add NPC, remove selected NPC. (done)
3. **Mouse selection:** Click to select NPC and show selected state in UI. (done)
4. **Smoke test:** Headless script loads scene and exercises add/remove. (done)

## Plans (v3)

- `docs/plan/v3-vr-offices.md`

## Definition of Done (DoD)

- Opening `vr_offices/VrOffices.tscn` and pressing Play shows a 3D scene with:
  - a floor you can’t fall through
  - gravity enabled for NPCs
  - a soft indoor light (no pitch-black scene)
  - an orbit camera you can rotate/zoom
- Clicking **Add NPC** spawns a Kenney character standing on the floor.
- Clicking an NPC selects it; clicking **Remove Selected** removes it.

## Verification (local)

Manual:

- Open the Godot project (GUI), open `vr_offices/VrOffices.tscn`, press Play.

Optional headless smoke test (requires a local Godot CLI):

- `godot4 --headless --script tests/test_vr_offices_smoke.gd`
- Windows PowerShell runner: `scripts\\run_godot_tests.ps1 -One tests\\test_vr_offices_smoke.gd`

## Known gaps (v3 backlog)

- Office interior set dressing (walls, desks, props).
- NPC movement/behaviors (walk to targets, idle animations).
- Dialogue (OpenAgentic integration) and agent-driven add/remove.
- Multi-select, keyboard selection, and contextual right-click menus.
