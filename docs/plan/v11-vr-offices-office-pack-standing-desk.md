# v11 — VR Offices Office Pack + Standing Desk (Workspace Furniture)

## Goal

1) Bring a CC `Office Pack-glb.zip` asset pack into the repo in a stable location under `res://assets/` (zip ignored), and generate a simple inventory under `vr_offices/`.

2) Add a first “workspace furniture” item: **Standing Desk**, placeable via RMB workspace context menu, with constraints and persistence.

## Scope

### In scope

- Assets:
  - Ignore `Office Pack-glb.zip` in `.gitignore`.
  - Extract `.glb` assets into `assets/office_pack_glb/`.
  - Add `vr_offices/OfficePack-glb-INVENTORY.md` listing extracted assets.
- Standing Desk:
  - New desk manager that tracks desks (bound to workspace ids) and spawns desk nodes.
  - Workspace context menu gains **Add Standing Desk…**
  - Placement mode:
    - Preview footprint (simple box) inside workspace.
    - LMB confirm; RMB/Esc cancel; `R` rotates 90°.
    - Constraints:
      - Must fit in workspace bounds.
      - Must not overlap existing desks in that workspace.
      - Per-workspace max desk count (start small, e.g. 3).
  - Persistence:
    - Save desks into VR Offices state json.
    - Load restores desks.
    - Deleting a workspace deletes its desks.
- Tests:
  - Unit tests for placement rules + serialization round-trip.

### Out of scope (v11)

- Multiple desk styles / furniture catalog UI
- Dragging/resizing desks after placement
- NPC interaction with furniture (sit/stand, pathfinding avoidance, etc.)

## Design (recommended approach)

### Data model

Represent each desk as:

- `id: String` (e.g. `desk_1`)
- `workspace_id: String` (e.g. `ws_3`)
- `pos: Vector3` (desk root position)
- `yaw: float` (rotation around Y; limit to `0` or `PI/2` initially)
- `kind: String` = `"standing_desk"` (reserved for future styles)

Serialize into state as:

```json
{
  "desk_counter": 1,
  "desks": [
    { "id": "desk_1", "workspace_id": "ws_3", "kind": "standing_desk", "pos": [x,y,z], "yaw": 0.0 }
  ]
}
```

### Placement UX

- RMB workspace → “Add Standing Desk…” enters placement mode.
- Show a semi-transparent **box footprint** preview:
  - Green-ish when valid, red-ish when invalid.
- LMB places:
  - Spawn the real desk model and animate in (simple tween: drop + scale).
- Cancel with RMB or Esc.
- Rotate with `R` (90° increments).

### Constraints

- Desk footprint is an axis-aligned XZ rectangle sized by constants (start with conservative defaults).
- Valid placement requires:
  - Footprint fully inside workspace rect.
  - No overlap with other desks’ footprints in same workspace.
  - Workspace desk count < max.

### Files

Create:

- `assets/office_pack_glb/*` (extracted `.glb`)
- `vr_offices/OfficePack-glb-INVENTORY.md`
- `vr_offices/furniture/StandingDesk.tscn`
- `vr_offices/furniture/StandingDesk.gd`
- `vr_offices/core/VrOfficesDeskManager.gd`
- Tests:
  - `tests/projects/vr_offices/test_vr_offices_workspace_desks_model.gd`
  - `tests/projects/vr_offices/test_vr_offices_workspace_desks_persistence.gd`

Modify:

- `.gitignore`
- `vr_offices/VrOffices.tscn` (add a `Furniture` root)
- `vr_offices/VrOffices.gd` (wire desk manager; keep thin)
- `vr_offices/ui/WorkspaceOverlay.gd` + `.tscn` (menu item + toast)
- `vr_offices/core/VrOfficesWorkspaceController.gd` (placement mode)
- `vr_offices/core/VrOfficesInputController.gd` (delegate RMB/key to workspace controller during placement)
- `vr_offices/core/VrOfficesSaveController.gd`
- `vr_offices/core/VrOfficesWorldState.gd`

## Tashan Loop Steps (v11)

### Task 1 — Assets (ignore zip + extract + inventory)

**Verify:** `git status --porcelain=v1`

### Task 2 — Desk model rules (TDD)

**Red:** run `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspace_desks_model.gd` (expect fail)

**Green:** implement `VrOfficesDeskManager` constraints + serialization.

### Task 3 — Desk persistence (TDD)

**Red:** run `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspace_desks_persistence.gd` (expect fail)

**Green:** extend world state/save controller, ensure desks round-trip.

### Task 4 — Placement UX + menu integration

Manual verify:

- Create a workspace, RMB it, choose Add Standing Desk, place it.
- Try placing outside/overlapping/too many desks; ensure rejection UX.
- Save + reload; desk still present.
- Delete workspace; desk disappears.

### Task 5 — Full verification

- Windows: `powershell -ExecutionPolicy Bypass -File scripts\\run_godot_tests.ps1`
- WSL2/Linux: follow `AGENTS.md`

