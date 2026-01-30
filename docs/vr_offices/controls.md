# Controls (VR Offices)

This document lists the current keyboard/mouse bindings in `vr_offices/`.

## Camera (when dialogue is closed)

- Orbit: **Right Mouse** drag
- Pan: **Middle Mouse** drag
- Zoom: **Mouse Wheel**

## NPC interaction (when dialogue is closed)

- Select NPC: **Left Click** on an NPC
- Move selected NPC: **Right Click** on the floor
- Talk: **Double Left Click** on an NPC (same as pressing **E**)
- Talk (keyboard): select an NPC, press **E**

## Workspaces (when dialogue is closed)

- Create workspace: **Left Click + Drag** on the floor, release to name the workspace
- Delete workspace: **Right Click** a workspace → **Delete workspace**

## Workspace furniture: Standing Desk

- Start placement: **Right Click** a workspace → **Add Standing Desk…**
- Placement mode (see on-screen action hint while active):
  - Move preview: move mouse over the floor
  - Confirm placement: **Left Click**
  - Cancel placement: **Right Click** (without dragging) or **Esc**
  - Rotate: press **R** (90°)

## Dialogue overlay (when dialogue is open)

- Exit dialogue (keyboard): press **Esc twice**
  - 1st Esc: stop typing (release input focus)
  - 2nd Esc: close the dialogue overlay
- Exit dialogue (mouse, click outside the panel on the dark backdrop):
  - **Right Click** once, or
  - **Double Left Click**

Input notes:

- While the dialogue overlay is open, mouse interactions are captured by the UI so the 3D camera won’t orbit/zoom/pan.

NPC behavior notes:

- A right-click move command temporarily disables wandering.
- The NPC uses a faster `sprint` movement (and `sprint` animation when available) while executing the command.
- When the NPC reaches the clicked point, it switches to `idle` and starts a “waiting for work” countdown (~60s).
- If nothing else happens during the countdown, the NPC resumes wandering.
- A yellow ring indicator appears at the clicked point and disappears once the NPC arrives.
