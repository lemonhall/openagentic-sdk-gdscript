# v10 — VR Offices Workspaces (Rectangular Zones)

## Goal

Add a new “workspace” feature to `vr_offices`:

- LMB click + drag + release on the **floor** → preview a rectangle → prompt for a name → create a persistent workspace zone.
- Zones are clamped to floor bounds, cannot overlap, are rendered semi-transparent (pastel colors), can be deleted via RMB context menu.

## Scope

### In scope

- **Input:**
  - LMB drag on floor starts a rectangle preview.
  - Release triggers a name-confirm popup.
  - RMB on a workspace opens a context menu to delete it.
  - Existing controls must keep working (NPC select/double-click talk, RMB floor move command).
- **Rendering:**
  - Preview uses a cyan glow feel (emissive + transparent).
  - Final workspace uses pastel colors, semi-transparent.
- **Constraints:**
  - Always inside floor bounds.
  - No overlap between workspaces (border-touch allowed).
- **Data model & persistence:**
  - Workspaces are saved into `user://openagentic/saves/<save_id>/vr_offices/state.json` via `VrOfficesWorldState`.
  - Load restores zones, names, ids, colors.
- **Modularity:**
  - Avoid adding feature logic into `vr_offices/VrOffices.gd`; implement via new controllers/modules.
- **Tests:**
  - Unit tests for geometry rules + serialization.

### Out of scope (v10)

- Selecting multiple NPCs via a rectangle
- Rotated rectangles / arbitrary polygons
- Resizing / renaming existing workspaces (can be v11)
- Advanced workspace behavior (agents, skills, hooks-driven behaviors)

## Design (recommended approach)

### Data

Represent a workspace as a world-aligned XZ rectangle:

- `id: String`
- `name: String`
- `rect_xz: Rect2` where:
  - `rect_xz.position = Vector2(min_x, min_z)`
  - `rect_xz.size = Vector2(width_x, width_z)`
- `color_index: int` (cycles through a pastel palette)

Serialized as:

```json
{
  "id": "ws_1",
  "name": "Design Team",
  "rect": [min_x, min_z, max_x, max_z],
  "color_index": 0
}
```

### World interactions

- A workspace is a `StaticBody3D` with:
  - a `PlaneMesh` for visuals (Y ≈ 0.02 to avoid z-fighting)
  - a thin `BoxShape3D` collider (for RMB picking)
- Use collision layers/masks:
  - Floor: `mask=1` (existing)
  - NPC: `mask=2` (existing)
  - Workspace: `mask=4` (new)

### Input priority rules

- When dialogue overlay is open: do not allow workspace interactions (existing input controller already blocks).
- RMB:
  1) If ray hits a workspace collider → show workspace context menu (consume).
  2) Else → existing RMB floor click = NPC move command.
- LMB:
  - If ray hits an NPC → existing NPC selection/double-click talk (no drag workspace).
  - Else if ray hits floor → allow drag-create flow:
    - press → arm drag
    - move beyond threshold → show preview
    - release → validate constraints → prompt name → create or cancel

### Persistence

Extend `VrOfficesWorldState.build_state()` to include:

- `workspaces: Array[Dictionary]`
- `workspace_counter: int` (optional helper for stable ids)

Load path:

- `VrOfficesSaveController.load_world()` calls:
  - `VrOfficesNpcManager.load_from_state_dict(state)`
  - `VrOfficesWorkspaceManager.load_from_state_dict(state)`

Save path:

- `VrOfficesSaveController.save_world(...)` builds state from both NPCs and workspaces.

## File plan (modular)

Create:

- `vr_offices/core/VrOfficesWorkspaceManager.gd`
  - In-memory list + nodes for workspaces
  - Geometry constraints (clamp, overlap checks)
  - `to_state_array()` / `load_from_state_dict()`
- `vr_offices/core/VrOfficesWorkspaceController.gd`
  - Input state machine for drag-create and RMB context menu
  - Manages preview mesh and prompts through UI overlay
- `vr_offices/workspaces/WorkspaceArea.tscn`
- `vr_offices/workspaces/WorkspaceArea.gd`
  - Visual + collision setup from rect + color
- `vr_offices/ui/WorkspaceOverlay.tscn`
- `vr_offices/ui/WorkspaceOverlay.gd`
  - “Create workspace” popup with name input
  - “Workspace” context menu with delete

Modify:

- `vr_offices/VrOffices.tscn` (add `Workspaces` node + overlay under `UI`)
- `vr_offices/VrOffices.gd` (wire new manager + controller, keep thin)
- `vr_offices/core/VrOfficesInputController.gd` (delegate workspace events first)
- `vr_offices/core/VrOfficesSaveController.gd` and/or `vr_offices/core/VrOfficesWorldState.gd` (persist workspaces)

Tests:

- `tests/projects/vr_offices/test_vr_offices_workspaces_model.gd`
  - clamp inside floor bounds
  - overlap rejection
  - color cycling
- `tests/projects/vr_offices/test_vr_offices_workspaces_persistence.gd`
  - save->load restores name + rect + color

## Tashan Loop Steps (v10)

### Task 1 — Add plan docs (this file + v10 index)

**Files:**
- Create: `docs/plan/v10-index.md`
- Create: `docs/plan/v10-vr-offices-workspaces.md`

**Verify:** `git status --porcelain=v1`

### Task 2 — Workspace data + persistence (TDD)

**Files:**
- Create: `vr_offices/core/VrOfficesWorkspaceManager.gd`
- Modify: `vr_offices/core/VrOfficesWorldState.gd`
- Modify: `vr_offices/core/VrOfficesSaveController.gd`
- Test: `tests/projects/vr_offices/test_vr_offices_workspaces_model.gd`
- Test: `tests/projects/vr_offices/test_vr_offices_workspaces_persistence.gd`

**Red:** run `scripts/run_godot_tests.ps1 -One tests\\test_vr_offices_workspaces_model.gd` (expect fail)

**Green:** implement minimal manager + serialize/deserialize.

### Task 3 — Workspace UI (create + context menu)

**Files:**
- Create: `vr_offices/ui/WorkspaceOverlay.tscn`
- Create: `vr_offices/ui/WorkspaceOverlay.gd`

**Tests:**
- Add a light UI test if feasible (create overlay, simulate signals).

### Task 4 — Drag-create + preview + RMB menu integration

**Files:**
- Create: `vr_offices/core/VrOfficesWorkspaceController.gd`
- Create: `vr_offices/workspaces/WorkspaceArea.tscn`
- Create: `vr_offices/workspaces/WorkspaceArea.gd`
- Modify: `vr_offices/core/VrOfficesInputController.gd`
- Modify: `vr_offices/VrOffices.tscn`
- Modify: `vr_offices/VrOffices.gd`

**Verify (manual):**
- Drag-create a few zones; ensure no overlap; delete via RMB.

### Task 5 — Full verification + ship

- Run full suite:
  - Windows: `powershell -ExecutionPolicy Bypass -File scripts\\run_godot_tests.ps1`
  - Linux/WSL: follow `AGENTS.md`
- `git add -A && git commit -m "v10: workspaces (slice N)" && git push`

