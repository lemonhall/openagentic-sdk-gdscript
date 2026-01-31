<!--
  v49 — VR Offices: Workspace desk preview cleanup bugfix
-->

# v49 — Workspace Desk Preview Cleanup Bugfix

## Vision (this version)

- Fix desk placement ending without Godot errors.
- Ensure the temporary `DeskPreview` ghost node is always cleaned up (placed or canceled).

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Desk preview lifecycle | Ending placement disposes preview without attempting to free `RefCounted`; regression test added | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_workspace_desk_preview_cleanup.gd` | done |

## Plan Index

- `docs/plan/v49-vr-offices-desk-preview-cleanup-bugfix.md`

## Evidence

Green:

- Linux: `timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_workspace_desk_preview_cleanup.gd` (PASS)
- Linux: `find tests/projects/vr_offices -type f -name 'test_*.gd' | LC_ALL=C sort | while IFS= read -r t; do timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script "res://$t"; done` (PASS)
