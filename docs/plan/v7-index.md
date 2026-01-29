# v7 Index — VrOffices Refactor (Code Health)

## Vision (v7)

Keep `vr_offices` maintainable as it grows by refactoring the main scene script into small, testable modules.

This iteration is **code health only**:

- no gameplay behavior changes intended
- keep public scene methods stable (tests + demo rely on them)
- preserve Godot 4.6 strict typing (warnings treated as errors)

## Milestones (facts panel)

1. **Plan:** define refactor scope and verification steps. (done)
2. **Refactor:** reduce `VrOffices.gd` size by extracting helpers. (done)
3. **Verify:** run full Godot test suite and ensure `vr_offices` demos still work. (done)

## Plans (v7)

- `docs/plan/v7-vr-offices-refactor.md`

## Definition of Done (DoD)

- `vr_offices/VrOffices.gd` is significantly smaller (target: ≤ 450 LOC).
- Extracted modules live under `vr_offices/core/` (and/or `vr_offices/data/`) with clear responsibilities.
- `scripts/run_godot_tests.ps1` and Linux/WSL workflows still pass for the full suite.

## Evidence

- `vr_offices/VrOffices.gd` is 450 lines (`wc -l vr_offices/VrOffices.gd`).
- Full test suite passes in headless mode (see `AGENTS.md` Linux Godot workflow).
