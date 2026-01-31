# VR Offices Workspace Decorations Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Each workspace auto-spawns a small set of wall + floor props (Office Pack) to reduce visual monotony without breaking interactions.

**Architecture:** Add a single decoration module invoked from the workspace scene binder to create headless-safe wrapper nodes and (when not headless) instance the actual `.glb` scenes under those wrappers.

**Tech Stack:** Godot 4.6, GDScript, existing VR Offices workspace manager/binder, headless tests.

### Task 1: Extend workspace nodes test (Red)

**Files:**
- Modify: `tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd`

**Step 1: Write the failing assertions**

- Require a `Decor` root under the spawned workspace node.
- Require expected child wrapper nodes for each prop.

**Step 2: Run test to verify it fails**

Run: `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd`  
Expected: FAIL (missing `Decor` / missing prop wrapper nodes)

### Task 2: Implement workspace decoration spawner (Green)

**Files:**
- Add: `vr_offices/core/workspaces/VrOfficesWorkspaceDecorations.gd`
- Add: `vr_offices/core/props/VrOfficesPropUtils.gd`
- Modify: `vr_offices/core/workspaces/VrOfficesWorkspaceSceneBinder.gd`

**Step 1: Implement decoration wrapper spawn**

- Create/find `Decor` under workspace node.
- Add wrapper nodes for:
  - Wall-hung: AnalogClock, Dartboard, Whiteboard, WallArt03, FireExitSign
  - Floor: FileCabinet, Houseplant, WaterCooler, TrashcanSmall
- Place them based on workspace rect size (against walls/corners; deterministic by workspace id).
- Disable collisions on instantiated models (collision layer/mask = 0) so floor raycasts (mask=1) remain stable.
- In headless mode, do not instance `.glb` scenes (wrappers only).

**Step 2: Wire into workspace spawn path**

- Call the decorations module from `VrOfficesWorkspaceSceneBinder.spawn_node_for(...)` after `configure(...)`.

**Step 3: Run test to verify it passes**

Run: `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspaces_nodes.gd`  
Expected: PASS

### Task 3: Verify suite + update evidence (Refactor/Verify)

**Files:**
- Modify: `docs/plan/v46-index.md` (Evidence section)

**Step 1: Run VR Offices suite**

Run: `scripts/run_godot_tests.sh --suite vr_offices`  
Expected: PASS

**Step 2: Update evidence**

- Record the PASS commands in `docs/plan/v46-index.md`.
