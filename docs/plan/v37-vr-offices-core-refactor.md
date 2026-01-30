# v37 — VR Offices: Core Modularization (No God Files)

## Goal

Keep `vr_offices/core` scalable by preventing “god files” and a flat directory structure:

- Reorganize `vr_offices/core/` into module subfolders.
- Refactor oversized scripts so **every** `.gd` file under `vr_offices/core/**` is **≤ 200 lines**.
- Keep behavior stable (API-compatible, tests green).

## Scope

In scope:

- Move + refactor scripts under `vr_offices/core/**`.
- Update `preload()`/`load()` paths in `vr_offices/` and `tests/`.
- Add a guard test to prevent regressions (new oversized files / files left in core root).

Out of scope:

- New features / UX changes.
- Changes under `demo_rpg/`.
- Refactors outside `vr_offices` unless required for path updates.

## Acceptance

- `tests/test_vr_offices_core_layout_guard.gd` passes (core layout + max line count).
- Desk/workspace related tests still pass (placement, persistence, overlay smoke).
- No `.gd` files remain directly in `res://vr_offices/core/` (they live in subfolders).
- No behavior regressions (existing tests are the contract).

## Files

Expected to move/refactor (non-exhaustive):

- Move existing: `vr_offices/core/*.gd` → `vr_offices/core/<module>/*.gd`
- Split oversized:
  - `vr_offices/core/VrOfficesDeskManager.gd`
  - `vr_offices/core/VrOfficesDeskIrcLink.gd`
  - `vr_offices/core/VrOfficesWorkspaceManager.gd`
  - `vr_offices/core/VrOfficesWorkspaceController.gd`
  - `vr_offices/core/VrOfficesNpcManager.gd`
  - `vr_offices/core/VrOfficesInputController.gd`
- Update call sites:
  - `vr_offices/VrOffices.gd`
  - `tests/test_vr_offices_*.gd`

## Steps (塔山开发循环)

1) **TDD Red**
   - Add `tests/test_vr_offices_core_layout_guard.gd` asserting:
     - `res://vr_offices/core/` contains **no** `.gd` files
     - All `.gd` files under `res://vr_offices/core/**` are **≤ 200** lines
   - Run it and confirm it fails on current layout.

2) **TDD Green**
   - Create module subfolders under `vr_offices/core/`.
   - Move scripts into their module folders and update all `preload()`/`load()` references.
   - Refactor oversized scripts by extracting cohesive helpers/controllers so each file ≤ 200.

3) **Refactor (still green)**
   - Remove duplication introduced during extraction.
   - Keep orchestrator scripts thin (wiring/forwarding only).

4) **Verify**
   - Run the guard test + a focused VR Offices regression set (excluding known-hanging tests).

## Risks

- Godot `preload()` path breakage (mitigation: `rg` all old paths; run smoke tests).
- Over-extraction creating circular dependencies (mitigation: keep helpers “leafy”, pass data in).
- Strict typing pitfalls (`null` inference) (mitigation: explicit nullable types in new modules).

