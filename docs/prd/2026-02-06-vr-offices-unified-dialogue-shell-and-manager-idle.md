# PRD — VR Offices: unified dialogue shell (left chat + right model) and manager idle autoplay

Date: 2026-02-06
Owner: VR Offices

## Problem

Current behavior has two UX gaps:

1) Manager dialogue preview may not autoplay idle animation, making the model feel static.
2) Normal NPC chat uses a different surface than manager chat, which makes speaker identity less obvious.

## Goals

- Make manager preview model autoplay a looping idle-like animation when available.
- Unify normal NPC dialogue with manager-style shell: left chat + right 3D model preview.
- Preserve existing manager-special storage isolation and manager context responsibilities.

## Non-goals

- Replacing the core `DialogueOverlay.tscn` component API.
- Expanding manager automation policy logic.
- Changing `demo_rpg` behavior.

## Requirements

### REQ-001 (Manager preview animation)
Manager dialogue preview should autoplay an idle-like animation (prefer names containing `idle`, fallback to `walk`, then first clip), and enforce loop when clip is non-looping.

### REQ-002 (Unified chat shell)
All standard NPC talk entrypoints (double click / key / direct `_enter_talk`) should open the manager-style shell (`left chat + right model`) instead of the legacy standalone dialogue overlay surface.

### REQ-003 (No regression in manager identity/storage)
Manager dialogue must continue using deterministic workspace-manager identity and manager-special workspace path conventions.

### REQ-004 (No regression in chat history and interactions)
Per-NPC chat history routing and camera/dialogue interaction behavior should remain correct after shell unification.

## Acceptance Criteria

1) Manager preview idle autoplay has a test and passes.
2) NPC talk opens manager-style shell and embedded dialogue, with NPC title shown.
3) Existing manager storage/path and manager role-context tests remain green.
4) Existing NPC dialogue smoke/history/double-click/focus tests remain green with updated expectations.
