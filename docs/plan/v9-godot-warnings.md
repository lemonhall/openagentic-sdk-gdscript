# v9 — Godot 4.6 Warnings Cleanup

## Goal

Eliminate editor warnings in `vr_offices` scripts so strict-mode builds remain stable and future changes are easier to reason about.

## Scope

- Fix only the reported warnings.
- No gameplay changes intended.

## Changes

- `vr_offices/npc/Npc.gd`
  - Cast `name` to `String` in `get_display_name()` to avoid ternary type mismatch.
  - Rename animation parameters from `name` → `clip` / `anim_name` to avoid shadowing base `Node.name`.
  - Rename move-command locals (`pos_xz`, `to_target`, `dir`) to avoid confusable re-declarations.
- `vr_offices/core/VrOfficesMoveController.gd`
  - Rename `floor` → `floor_body` to avoid shadowing global `floor()`.
- `vr_offices/VrOffices.gd`
  - Rename `floor` → `floor_body` to avoid shadowing global `floor()`.
- `vr_offices/camera/OrbitCameraRig.gd`
  - Rename local `scale` → `pan_scale` to avoid shadowing `Node3D.scale`.

## Acceptance

- No warnings for the above files when opening the project in Godot 4.6.
- Headless tests still pass.

