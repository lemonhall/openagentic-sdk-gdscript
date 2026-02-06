# VR Offices: Manager desk click dialogue + manager-special storage PRD

## Vision

The workspace manager is a special NPC. Players should click the manager desk and immediately enter a manager-specific chat view (chat on the left, manager model on the right). Manager conversation/session/workspace files must be isolated per workspace and stored in a stable manager-specific path (not mixed with auto-spawn `npc_XX` paths).

## Requirements

### REQ-001 — Click manager desk opens manager dialogue UI

- Clicking the workspace default manager desk opens a dialogue overlay.
- The manager dialogue overlay layout is:
  - left: same chat interaction pattern as NPC dialogue (history, send, stream output)
  - right: manager 3D preview model
- Manager desk should be pickable in-world (dedicated pick collider + group) and not interfere with existing desk/vending interactions.

### REQ-002 — Manager has fixed, workspace-isolated storage root

- Manager identity must be deterministic per workspace (stable ID, not auto-increment NPC IDs).
- Manager session/memory/workspace paths must resolve to a manager-special root under the save:
  - `user://openagentic/saves/<save_id>/workspaces/<workspace_id>/manager/...`
- Isolation remains intact: each workspace manager only sees its own workspace root.

### REQ-003 — Manager role prompt includes workspace active NPC context

- Manager turns should include manager-role guidance:
  - manager is responsible for coordinating active NPCs in the workspace
- Runtime context should include a concise snapshot of currently active NPCs in that workspace.

### REQ-004 — Automated regression tests

- Add/adjust tests to cover:
  - manager desk pickability + click opens manager dialogue
  - manager path resolution to workspace manager root

## Non-Goals

- Full manager orchestration policy engine.
- New permissions model.
- Replacing existing NPC dialogue UI for non-manager NPCs.
