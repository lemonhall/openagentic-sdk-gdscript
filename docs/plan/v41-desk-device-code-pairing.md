# v41 — Desk Device-Code Pairing (Game Side)

## Goal

Add a simple operator UX to pair a **desk** with a **remote Rust daemon** using a device code:

- Operator right-clicks a desk → selects “绑定设备码” → enters code.
- Desk stores the code (persisted in `vr_offices/state.json`).
- Desk IRC link re-derives channel name to include both `desk_id` and `device_code`, and joins it quickly.

## Non-Goals (v41)

- Implementing the remote agent / OA1 server-side execution.
- Advanced security/authentication (this is a config pairing mechanism).
- Supporting multiple device codes per desk.

## Device Code Rules (canonicalization + validation)

- Input is **case-insensitive** and may include separators like `-` / `_` / spaces.
- Canonical form:
  - keep only ASCII `[A-Za-z0-9]`
  - uppercase result
- Valid if canonical length is between **6 and 16** characters (inclusive).

## Channel Naming (paired desk)

When a desk has a non-empty device code, derive:

```
#oa_desk_<desk>_dev_<code>_<hash>
```

Where:

- `<desk>` is the sanitized `desk_id`
- `<code>` is the sanitized canonical device code
- `<hash>` is a short deterministic suffix (first 6 hex chars of SHA-256 of `save_id:workspace_id:desk_id:device_code`)

This keeps the name debug-friendly (contains desk id + device code) while preserving uniqueness.

If no device code is set, the existing `derive_channel_for_workspace(...)` naming stays unchanged.

## Acceptance

- A desk has a `device_code` field in persisted state and loads it back.
- Right-click desk shows a popup menu containing “绑定设备码”.
- Submitting a valid device code updates the desk model and triggers DeskIrcLink desired channel re-derivation.
- DeskIrcLink can switch from old channel to new channel by PART+JOIN without requiring a full reconnect (best-effort).

## Files

Create:

- `vr_offices/ui/DeskOverlay.tscn`
- `vr_offices/ui/DeskOverlay.gd`
- `tests/projects/vr_offices/test_vr_offices_desk_device_code_persistence.gd`
- `tests/projects/vr_offices/test_vr_offices_desk_device_code_channel_derivation.gd`

Modify:

- `vr_offices/VrOffices.tscn`
- `vr_offices/VrOffices.gd`
- `vr_offices/core/input/VrOfficesInputController.gd`
- `vr_offices/core/desks/VrOfficesDeskModel.gd`
- `vr_offices/core/desks/VrOfficesDeskManager.gd`
- `vr_offices/core/desks/VrOfficesDeskSceneBinder.gd`
- `vr_offices/core/desks/VrOfficesDeskIrcLink.gd`
- `vr_offices/core/irc/VrOfficesIrcNames.gd`
- `vr_offices/furniture/StandingDesk.gd`

## Steps (塔山开发循环)

1) **Red**: add failing tests for:
   - desk state persists `device_code`
   - derived channel contains `desk_id` + `device_code` when set
2) **Green**: implement minimal model + naming + link changes until tests pass.
3) **Green**: add UI overlay + RMB flow; keep behavior conservative (only intercept RMB when a desk is clicked).
4) **Refactor**: keep controllers small; avoid “god files”; ensure strict typing rules.
5) **Verify**:
   - `scripts/run_godot_tests.sh --suite vr_offices`
   - `scripts/run_godot_tests.sh --suite openagentic` (guard against regressions)

## Risks

- Input conflicts: RMB currently triggers move/context menu; ensure desk RMB intercept happens only when raycast picks a desk.
- Channel length: enforce device code max length (16) so `channellen_default=50` stays safe.
- Persistence migration: older saves may not have `device_code`; must treat as empty.

