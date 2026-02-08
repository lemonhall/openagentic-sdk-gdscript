# v106 — VR Offices: Defer dialogue open disk I/O

## Problem

On NPC double-click, players observe a noticeable hitch **before the overlay appears**. Even if history rendering/loading is incremental, any synchronous disk access in the same frame as `DialogueOverlay.open()` can delay the first draw.

Two culprits in the open path:

- `DialogueOverlay.open()` synchronously reading `events.jsonl` length for the header label.
- `VrOfficesDialogueController.enter_talk()` starting history load immediately after `open()` (even “incremental” loaders may open/seek files synchronously).

## Scope

- Defer session log size refresh (`events.jsonl=<size>`) to the next frame.
- Defer starting history load to the next frame (so open frame does no disk I/O).

## Acceptance (Hard DoD)

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd -TimeoutSec 240` → PASS
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0

## Update (2026-02-08)

Deferring disk I/O to “next frame” helps, but it may still execute before the first draw on some platforms/builds. The robust fix is to avoid main-thread disk I/O entirely via a background job (see v107).
