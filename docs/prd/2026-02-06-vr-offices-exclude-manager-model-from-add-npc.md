# PRD — VR Offices: exclude manager model from `add_npc` pool

Date: 2026-02-06
Owner: VR Offices

## Problem

`add_npc` currently allocates from all profile models, including the manager's model (`character-male-d.glb`). This can create non-manager NPCs with the same visual identity as manager, breaking uniqueness and role clarity.

## Goals

- Ensure manager model is never allocated by `add_npc`.
- Keep manager model reserved as a special identity in scene semantics.
- Preserve existing manager desk/dialogue/storage behavior.

## Non-goals

- Migrating legacy saves that already contain NPCs using manager model.
- Changing manager storage path conventions.

## Requirements

### REQ-001
`add_npc` model allocation must exclude `MANAGER_MODEL_PATH`.

### REQ-002
The exclusion must be stable even when profile slots are released/re-added (remove/add cycles).

### REQ-003
Expected max `add_npc` capacity reflects non-manager profiles only.

### REQ-004
No regression in manager desk/dialogue/storage flows.

## Acceptance Criteria

1) A dedicated test confirms manager model is never present after filling `add_npc` capacity.
2) Smoke test expectations align to non-manager profile capacity.
3) Manager desk/dialogue/storage tests and VR Offices suite remain green.
