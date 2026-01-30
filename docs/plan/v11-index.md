# v11 Index — VR Offices Workspace Furniture (Standing Desk + Office Pack)

## Vision (v11)

Bring in a CC office asset pack and let the player add a first piece of “furniture” to a workspace: a **Standing Desk** that is bound to a specific workspace, placed via a simple, game-like placement flow (preview → confirm), and persisted in VR Offices save/load.

## Milestones (facts panel)

1. **Plan:** write an executable v11 plan with modular architecture + tests. (done)
2. **Assets:** ignore local zip, extract Office Pack to a stable path, and add an inventory/manifest. (done)
3. **Model:** add a desk data model + persistence + cleanup on workspace delete. (done)
4. **Placement:** RMB workspace menu → “Add Standing Desk…” → preview + constraints + confirm/cancel. (done)
5. **Verify:** run headless test(s) for model + persistence. (done)

## Plans (v11)

- `docs/plan/v11-vr-offices-office-pack-standing-desk.md`

## Definition of Done (DoD)

- `Office Pack-glb.zip` is ignored by git, and its contents are extracted under `res://assets/`.
- `vr_offices` includes a human-readable inventory of the extracted assets.
- RMB on a workspace opens a context menu with:
  - **Add Standing Desk…**
  - **Delete workspace** (existing)
- Choosing **Add Standing Desk…** enters a placement mode:
  - Shows a preview footprint in the workspace.
  - Player can confirm placement (LMB) or cancel (RMB/Esc).
  - Placement respects constraints:
    - Must fit inside the workspace.
    - Must not overlap existing desks.
    - Must respect a per-workspace desk limit.
- Placed desks are bound to a workspace id, and:
  - Persist in `user://openagentic/saves/<save_id>/vr_offices/state.json`.
  - Are removed if their workspace is deleted.
- `vr_offices/VrOffices.gd` remains a thin orchestrator (no large new feature logic).

## Verification

- Windows:
  - `powershell -ExecutionPolicy Bypass -File scripts\\run_godot_tests.ps1`
- WSL2 + Linux Godot:
  - Follow `AGENTS.md` “Running tests (WSL2 + Linux Godot)”.

## Evidence

- Tests added (v11):
  - `tests/test_vr_offices_workspace_desks_model.gd`
  - `tests/test_vr_offices_workspace_desks_persistence.gd`
