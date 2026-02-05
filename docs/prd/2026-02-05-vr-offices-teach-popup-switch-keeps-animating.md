# VR Offices: Teach popup switching keeps preview animating PRD

## Problem

In the Teach-skill NPC picker, opening the popup plays idle correctly, but after pressing `<` / `>` to switch NPCs, the preview animates for a moment then stops.

## Root Cause (expected)

The preview `SubViewport` is being set to a one-shot update mode after switching, which stops rendering subsequent animation frames.

## Requirements

### REQ-001 — Switching NPCs does not stop preview updates

- While the popup is visible, the preview viewport must keep updating so animations continue to render.
- Switching NPCs with `<` / `>` must **not** set the viewport to `UPDATE_ONCE`.

### REQ-002 — Automated regression test (headless-safe)

- Add a test that:
  - opens the popup with 2 dummy NPC entries,
  - triggers a switch,
  - waits for the tween to finish,
  - asserts `TeachPreviewViewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS`.
- Because tests run headless, the popup must provide a debug-only way to force “non-headless” behavior for this test.

## Non-Goals

- No changes to tween visuals or animation selection (handled in earlier slices).

