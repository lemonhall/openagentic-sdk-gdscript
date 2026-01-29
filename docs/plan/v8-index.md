# v8 Index — VrOffices Deep Refactor (Maintainability)

## Vision (v8)

`vr_offices` will keep growing fast. Keep the main scene script as a thin orchestrator so future features can be added as isolated modules with tests.

## Milestones (facts panel)

1. **Plan:** define deep refactor target and verification. (done)
2. **Refactor:** reduce `vr_offices/VrOffices.gd` to ~200 LOC while keeping behavior stable. (done)
3. **Verify:** run the Godot headless test suite. (pending; see verification commands)

## Plans (v8)

- `docs/plan/v8-vr-offices-deep-refactor.md`

## Definition of Done (DoD)

- `vr_offices/VrOffices.gd` is ~200 LOC (target: ≤ 200, soft cap: ≤ 220).
- Responsibilities moved into focused modules under `vr_offices/core/`.
- No intended gameplay changes; existing `vr_offices` tests still pass.

## Evidence

- `vr_offices/VrOffices.gd` is 172 lines: `wc -l vr_offices/VrOffices.gd`.
- New modules added:
  - `vr_offices/core/VrOfficesNpcManager.gd`
  - `vr_offices/core/VrOfficesAgentBridge.gd`
  - `vr_offices/core/VrOfficesSaveController.gd`

## Verification (run locally)

- Windows:
  - `powershell -ExecutionPolicy Bypass -File scripts\\run_godot_tests.ps1`
- Single file while iterating:
  - `powershell -ExecutionPolicy Bypass -File scripts\\run_godot_tests.ps1 -One tests\\test_vr_offices_smoke.gd`

