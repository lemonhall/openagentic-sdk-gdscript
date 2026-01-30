# VR Offices Standing Desk (Workspace Furniture) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Import a CC Office Pack and add a first placeable, workspace-bound Standing Desk with basic placement constraints and persistence.

**Architecture:** Keep `vr_offices/VrOffices.gd` as a thin orchestrator. Implement desk state + spawning in a new `VrOfficesDeskManager`, integrate via `WorkspaceOverlay` (menu/toast) and `VrOfficesWorkspaceController` (placement mode), and persist via `VrOfficesWorldState` + `VrOfficesSaveController`.

**Tech Stack:** Godot 4.6 (GDScript), VR Offices modules/controllers, headless script tests under `tests/`.

## Plan Reference

The authoritative, versioned plan for this slice is:

- `docs/plan/v11-index.md`
- `docs/plan/v11-vr-offices-office-pack-standing-desk.md`

This file exists to match the `docs/plans/` convention and points to the v11 plan docs to avoid duplication.

