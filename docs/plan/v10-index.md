# v10 Index — VR Offices Workspaces (Rectangular Zones)

## Vision (v10)

Let the player create named rectangular “workspaces” on the office floor via classic drag-select, with strong constraints (inside floor, no overlap), clear visuals, right-click removal, and full save/load persistence.

## Milestones (facts panel)

1. **Plan:** write an executable v10 plan with modular architecture + tests. (done)
2. **Core:** data model + persistence for workspaces, with unit tests. (done)
3. **UI:** create-confirm dialog + right-click context menu (delete), with tests where feasible. (pending)
4. **Input/Preview:** LMB drag-create + preview (cyan glow), and RMB on workspace opens menu; keep existing NPC controls. (pending)
5. **Verify:** run full headless test suite (Linux/WSL and/or Windows). (pending)

## Plans (v10)

- `docs/plan/v10-vr-offices-workspaces.md`

## Definition of Done (DoD)

- Player can LMB drag on the **floor** to preview a rectangle and on release is prompted to name it.
- Workspace creation hard rules:
  - Always clamped inside floor bounds.
  - Cannot overlap any existing workspace (border-touch allowed).
- A created workspace:
  - Renders as a semi-transparent rectangle on the floor (pastel colors cycling).
  - Has a persistent name.
  - Can be right-clicked to open a small context menu with **Delete**.
- Workspaces are part of VR Offices world state and survive save/load.
- `vr_offices/VrOffices.gd` remains a thin orchestrator (no large new feature logic).
- Tests cover at least: bounds clamping, overlap prevention, serialization round-trip.

## Verification

- Windows:
  - `powershell -ExecutionPolicy Bypass -File scripts\\run_godot_tests.ps1`
- WSL2 + Linux Godot:
  - Follow `AGENTS.md` “Running tests (WSL2 + Linux Godot)”.
