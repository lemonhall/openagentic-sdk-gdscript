# v15 Index — VR Offices Desk Rotation Placement Bugfix

## Vision (v15)

Desk placement should honor the player’s preview rotation: the placed desk’s orientation must match the ghost preview orientation (0°/90°/180°/270°).

## Milestones (facts panel)

1. **Plan:** write an executable v15 plan with tests. (todo)
2. **Fix:** update yaw snapping / footprint logic for 4 rotations. (todo)
3. **Verify:** regression test + headless run. (todo)

## Plans (v15)

- `docs/plan/v15-vr-offices-desk-rotation-bugfix.md`

## Definition of Done (DoD)

- Rotating the ghost preview to 180° or 270° results in a placed desk with the same yaw.
- Desk footprint logic treats 90° and 270° as “swapped X/Z”.
- Tests cover the 4-snap yaw behavior.

