# v12 Index — VR Offices Desk Placement UX + RMB Conflict Fix

## Vision (v12)

Refine the Standing Desk placement interaction so it feels predictable and does not break existing core interactions:

- Placement rotation supports 0°/90°/180°/270° (not just a 0↔90 toggle).
- In placement mode, **RMB rotates** (Esc cancels).
- The ghost preview clearly indicates **valid vs invalid** placement.
- **NPC RMB move** continues to work even when clicking inside a workspace (no hard conflict with workspace RMB menu).

## Milestones (facts panel)

1. **Plan:** write an executable v12 plan with tests + docs. (done)
2. **Input:** RMB behavior in placement mode + rotation cycling. (done)
3. **UX:** preview validity tint is clearly visible. (done)
4. **Conflict:** selected NPC RMB move works inside workspaces; workspace menu remains accessible. (done)
5. **Verify:** add regression test + run headless tests. (done)

## Plans (v12)

- `docs/plan/v12-vr-offices-desk-placement-ux.md`

## Definition of Done (DoD)

- Placement mode controls:
  - Confirm: LMB
  - Rotate: R or RMB (snap 90° per step, cycles through 4 orientations)
  - Cancel: Esc
- When an NPC is selected, RMB on the floor (including within a workspace) issues a move command (indicator appears).
  - Workspace RMB menu remains reachable (documented modifier).
- Ghost preview clearly communicates validity (visible tint difference).
- Tests:
  - `tests/test_vr_offices_right_click_move.gd` includes a regression case for RMB move inside a workspace.

## Verification

- Windows:
  - `powershell -ExecutionPolicy Bypass -File scripts\\run_godot_tests.ps1`
- WSL2 + Linux Godot:
  - Follow `AGENTS.md` “Running tests (WSL2 + Linux Godot)”.

## Evidence

- Headless tests (Linux Godot):
  - `tests/test_vr_offices_right_click_move.gd`
  - `tests/test_vr_offices_workspace_desks_model.gd`
  - `tests/test_vr_offices_workspace_desks_persistence.gd`
  - `tests/test_vr_offices_smoke.gd`
  - `tests/test_vr_offices_workspace_overlay.gd`
