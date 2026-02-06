# PRD — VR Offices: avoid overlap between dialogue shell and NPC skills overlay

Date: 2026-02-06
Owner: VR Offices

## Problem

When opening NPC skills management from the dialogue shell, users can see visual overlap between the dialogue shell and skills overlay. This causes readability issues and interaction confusion.

## Goals

- Ensure skills overlay opens without dialogue shell overlap.
- Keep skills entry flow from dialogue intact.
- Avoid regressions to existing dialogue shell and skills overlay behavior.

## Non-goals

- Rework entire UI layering architecture.
- Add back-stack navigation between shell and skills views.

## Requirements

### REQ-001
When `skills_pressed` is handled, dialogue shell should be hidden/closed before or during skills overlay open.

### REQ-002
Skills overlay still opens correctly for the target NPC.

### REQ-003
No regressions in shell-based NPC dialogue and existing NPC skills overlay tests.

## Acceptance Criteria

1) A regression test verifies dialogue shell is hidden after opening skills overlay from dialogue.
2) Existing skills overlay and dialogue shell tests remain green.
3) VR Offices suite remains green.
