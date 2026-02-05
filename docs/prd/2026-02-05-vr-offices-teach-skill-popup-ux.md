# VR Offices: Teach-skill popup UX polish PRD

## Vision

Make the “Teach Skill” NPC picker feel coherent and readable:

- The preview should **not** show the live game world or moving NPCs from the main scene.
- The selected NPC should be framed at a comfortable size.
- Switching NPCs with `<` / `>` should feel smooth (basic tween).

## Requirements

### REQ-001 — Preview viewport uses an isolated 3D world

- The popup preview must render inside a `SubViewport` that does **not** share the main scene world.
- The preview must not show unrelated world elements (e.g. other NPCs moving in the office).

Acceptance (automated):
- A test asserts `TeachPreviewViewport.own_world_3d == true`.

### REQ-002 — Preview framing: NPC is not tiny

- Adjust camera/FOV (and/or distance) based on the preview model bounds so the NPC occupies a reasonable portion of the preview (MVP: “visibly large”).
- If bounds can’t be computed (no mesh), fallback to a sensible default.

### REQ-003 — Smooth `<` / `>` switching (MVP tween)

- When cycling NPC selection:
  - fade out preview + label,
  - swap selection,
  - fade in.
- Disable the nav buttons during the tween to avoid double-trigger glitches.
- In headless/server builds, switch instantly (no tween, no preview).

## Non-Goals

- Fancy 3D turntable / rotation / particle effects.
- Speech bubbles / SFX / animations.
- Perfect “cinematic” framing for every model.

