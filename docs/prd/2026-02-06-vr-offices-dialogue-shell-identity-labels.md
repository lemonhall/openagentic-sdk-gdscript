# PRD — VR Offices: dialogue shell identity labels (target + workspace)

Date: 2026-02-06
Owner: VR Offices

## Problem

After unifying dialogues into the manager-style shell (left chat, right model), users still need explicit identity context in the right panel, especially during multi-NPC operations.

## Goals

- Show current chat target name in the right model panel.
- Show current workspace identity in the right model panel.
- Keep manager and normal NPC behaviors consistent.

## Non-goals

- Rework dialogue protocol/runtime state storage.
- Replace `DialogueOverlay` internals.
- Expand manager workflow policy.

## Requirements

### REQ-001 (Identity label)
The shell right panel must include an explicit label for current target identity.

### REQ-002 (Workspace label)
The shell right panel must include an explicit label for workspace context. If unknown, it must show a global/default indicator.

### REQ-003 (Manager/NPC consistency)
Both manager entry (`open_for_manager`) and normal NPC entry (`open_for_npc`) must update identity/workspace labels correctly.

### REQ-004 (No regression)
Existing manager storage path behavior and existing dialogue shell flows must remain stable.

## Acceptance Criteria

1) A test verifies shell has identity/workspace labels and both values update when switching manager/NPC context.
2) Normal NPC chat opens shell with target/workspace labels.
3) Existing manager path + shell + smoke/layout guard tests remain green.
