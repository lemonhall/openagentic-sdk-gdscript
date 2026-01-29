# v9 Index — Clean Up Godot 4.6 Warnings

## Vision (v9)

Keep the project safe under Godot 4.6 strict mode by eliminating editor warnings that can later become errors or hide real issues.

## Milestones (facts panel)

1. **Fix warnings:** remove known warnings in `vr_offices` scripts. (done)
2. **Verify:** run the Godot headless test suite and ensure editor opens cleanly. (pending; see verification)

## Plans (v9)

- `docs/plan/v9-godot-warnings.md`

## Evidence

- Warnings addressed:
  - `Npc.gd`: ternary type mismatch, `name` shadowing, confusable local declarations
  - `VrOfficesMoveController.gd` / `VrOffices.gd`: `floor` shadowing global `floor()`
  - `OrbitCameraRig.gd`: local `scale` shadowing `Node3D.scale`

## Verification

- Run all tests:
  - `powershell -ExecutionPolicy Bypass -File scripts\\run_godot_tests.ps1`
- Open Godot editor and confirm no warnings at startup:
  - `Npc.gd`, `VrOfficesMoveController.gd`, `VrOffices.gd`, `OrbitCameraRig.gd`

