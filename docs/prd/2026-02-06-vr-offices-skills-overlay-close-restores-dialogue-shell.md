# PRD — VR Offices: closing NPC skills returns to previous dialogue shell

Date: 2026-02-06
Owner: VR Offices

## Problem

After opening NPC skills from the dialogue shell, closing the skills overlay leaves users without the previous dialogue context. This creates a broken flow and makes continuation awkward.

## Goals

- Restore the previous dialogue shell when skills overlay is closed.
- Keep restored dialogue targeted to the same NPC.
- Preserve existing overlay behavior (skills open should still hide shell).

## Non-goals

- Build a generic multi-screen navigation stack.
- Redesign the dialogue shell layout.

## Requirements

### REQ-001
When NPC skills overlay is opened from dialogue and then closed, the dialogue shell should become visible again.

### REQ-002
The restored dialogue should target the same NPC identity (`npc_id`) as before entering skills.

### REQ-003
No regressions to existing behavior: opening skills still hides shell; existing skills/dialogue/smoke tests remain green.

## Acceptance Criteria

1) A regression test verifies shell restores after `VrOfficesNpcSkillsOverlay.close()`.
2) Existing overlap test (skills open hides shell) remains green.
3) Existing NPC skills, dialogue shell layout, and smoke tests remain green.
