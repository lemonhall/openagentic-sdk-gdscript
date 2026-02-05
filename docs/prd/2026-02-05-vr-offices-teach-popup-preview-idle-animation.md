# VR Offices: Teach popup preview idle animation PRD

## Vision

In the Teach-skill NPC picker, the preview NPC should not stand in T-pose. It should play a simple looped idle (or a reasonable fallback animation) inside the preview mini-world.

## Requirements

### REQ-001 — Autoplay idle animation when available

- When the preview model scene contains an `AnimationPlayer` with animations:
  - Prefer an animation whose name contains `idle` (case-insensitive).
  - Else prefer one containing `walk`.
  - Else play the first available clip.
- Ensure the chosen animation loops (if the clip is not already looped).

### REQ-002 — Preview safety

- Preview must remain isolated (`SubViewport.own_world_3d = true`), and must not run gameplay logic.
- Allow animation playback without enabling unrelated node scripts.

### REQ-003 — Automated test (headless-safe)

- Add a headless-safe test that builds a simple node tree containing an `AnimationPlayer` + a minimal `Animation`, calls the popup helper, and asserts the player is playing.

## Non-Goals

- Fancy turntable rotation, gestures, or per-skill effects.
- Perfect animation selection for every vendor model (heuristic selection is fine).

