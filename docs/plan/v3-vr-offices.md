# v3 Plan — VR Offices (3D scene + NPC add/remove)

## Goal

Deliver a minimal 3D office-sim slice under `vr_offices/` that supports:

- god-view orbit camera
- a physics floor with gravity
- UI actions to add/remove NPCs
- mouse-click NPC selection
- a modern dialogue overlay (selected NPC + `E`)
- autosave/load office state per save slot

## Scope

In scope:

- New folder `vr_offices/` with a main scene and scripts.
- Import-ready Kenney GLB characters (extracted from `kenney_mini-characters.zip`).
- A small UI panel (Add / Remove Selected + selected label).
- Dialogue overlay UI (stream-friendly) and basic per-NPC history replay from session store.
- Autosave: office roster persisted per `save_id`, plus forced save-on-quit overlay.
- Headless tests for smoke, dialogue UI, per-NPC history, and persistence.

Out of scope:

- Deep agent-driven dialogue behaviors (prompting, tools, world summary compaction).
- NPC AI navigation or complex interactions.
- Full interior art.

## Acceptance

- Running `vr_offices/VrOffices.tscn`:
  - camera orbit/zoom works
  - scene is lit
  - clicking **Add NPC** spawns a character with a collider
  - clicking a character selects it; UI shows which is selected
  - clicking **Remove Selected** removes it
- Selecting an NPC and pressing **E** opens a dialogue overlay; overlay blocks camera input.
- Switching to a different NPC shows that NPC’s own dialogue history (no history bleed).
- Closing and reopening the scene restores the previous NPC roster (autosave).
- Tests:
  - `tests/test_vr_offices_smoke.gd` loads the scene and exercises add/remove.
  - `tests/test_vr_offices_dialogue_ui.gd` validates dialogue overlay basics.
  - `tests/test_vr_offices_per_npc_history.gd` validates per-NPC history isolation.
  - `tests/test_vr_offices_persistence.gd` validates autosave/load.

## Files

Create:

- `vr_offices/VrOffices.tscn`
- `vr_offices/VrOffices.gd`
- `vr_offices/camera/OrbitCameraRig.tscn`
- `vr_offices/camera/OrbitCameraRig.gd`
- `vr_offices/npc/Npc.tscn`
- `vr_offices/npc/Npc.gd`
- `vr_offices/ui/VrOfficesUi.tscn`
- `vr_offices/ui/VrOfficesUi.gd`
- `scripts/setup_kenney_mini_characters.sh`
- `tests/test_vr_offices_smoke.gd`
- `vr_offices/ui/DialogueOverlay.tscn`
- `vr_offices/ui/DialogueOverlay.gd`
- `vr_offices/ui/SavingOverlay.tscn`
- `vr_offices/ui/SavingOverlay.gd`
- `tests/test_vr_offices_dialogue_ui.gd`
- `tests/test_vr_offices_per_npc_history.gd`
- `tests/test_vr_offices_persistence.gd`

Modify:

- `docs/plan/v3-index.md`
- `README.md` (brief mention)
- `README.zh-CN.md` (brief mention)
- `project.godot` (optional: main scene switch)

## Steps (Tashan / TDD)

1. **Red:** add `tests/test_vr_offices_smoke.gd` that tries to load `vr_offices/VrOffices.tscn` and fails because it doesn’t exist yet.
2. **Green:** create the minimal scene + scripts so the smoke test loads and can call `add_npc()` / `remove_selected()`.
3. **Green:** implement orbit camera + floor + light, keep smoke test green.
4. **Green:** implement UI wiring and mouse selection; extend smoke test with selection + removal.
5. **Refactor:** keep `VrOffices.gd` small and split camera / NPC / UI logic into their own scripts.

## Risks

- Import pipeline differences between Godot 4 builds (GLB import settings) → keep NPC visuals tolerant (fallback mesh if GLB missing).
- WSL2/Windows Godot headless runs can be flaky → keep smoke test optional and ensure manual verification is documented.
- `warning treated as error` in Godot 4.6 strict mode → avoid Variant type inference from `null`/`JSON.parse_string`/`FileAccess.open`.
