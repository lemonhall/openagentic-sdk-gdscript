# v105 — VR Offices: Manager dialogue preview async load

## Problem

Players observe a 1–2s hitch **before** the dialogue overlay appears on NPC double-click. Since dialogue history loading/rendering is now frame-sliced, the remaining likely blocker is the manager dialogue overlay’s **3D preview model** work: synchronous `load()` + instantiate + mesh bounds scanning in the talk-open call path.

## Scope

- Make NPC/manager preview model loading **deferred + threaded** so the overlay can appear immediately.
- Show a lightweight placeholder preview immediately; replace with the real model once loaded.
- Add a project setting to **disable preview** (for isolation / low-spec fallback).
- Keep existing preview camera framing helpers used by tests.

## Non-scope

- Perfect preview framing on first frame (okay if camera frames later).
- Broader asset streaming / cache subsystem.

## Acceptance (Hard DoD)

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_manager_dialogue_preview_async_load.gd -TimeoutSec 240` → PASS
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0

