# Kenney Mini Characters 1 — Embedded Animations

Kenney Mini Characters 1 (`assets/kenney/mini-characters-1/*.glb`) ships with embedded skeletal animations.

This project uses `idle` and `walk` for basic NPC wandering in `vr_offices`.

## Animation list (as found in the GLBs)

All 12 characters contain the same set of animations (32):

- `static`
- `idle`
- `walk`
- `sprint`
- `jump`
- `fall`
- `crouch`
- `sit`
- `drive`
- `die`
- `pick-up`
- `emote-yes`
- `emote-no`
- `holding-right`
- `holding-left`
- `holding-both`
- `holding-right-shoot`
- `holding-left-shoot`
- `holding-both-shoot`
- `attack-melee-right`
- `attack-melee-left`
- `attack-kick-right`
- `attack-kick-left`
- `interact-right`
- `interact-left`
- `wheelchair-sit`
- `wheelchair-look-left`
- `wheelchair-look-right`
- `wheelchair-move-forward`
- `wheelchair-move-back`
- `wheelchair-move-left`
- `wheelchair-move-right`

## How this list was extracted

The repo includes a helper that parses GLB animation entries:

- `python3 scripts/list_glb_animations.py assets/kenney/mini-characters-1/character-male-a.glb`

## Notes for gameplay

- Many animations are intended to be **one-shots** (e.g. `emote-*`, `interact-*`).
- `idle`/`walk` are good candidates to loop.

