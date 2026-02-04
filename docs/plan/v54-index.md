<!--
  v54 — Settings UX: Media config + health + open folder + send log
-->

# v54 — Settings UX (Media config + health + open folder + send log)

## Why (problem statement)

Current media service configuration relies on environment variables, which is awkward for in-game usage and debugging.

This version improves UX by turning the existing “IRC…” button into a “Settings…” entry point, and adding a Media tab to configure the media service, test health, open the receive cache folder, and view send logs.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | UI entry | Left-top button text becomes `Settings…` and opens the overlay | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_ui_settings_button_label.gd` | done |
| M2 | Media tab | Settings overlay has a `Media` tab with base URL + token + health check | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_settings_overlay_has_media_tab.gd` | done |
| M3 | Persistence | Media config persists per save slot under `user://openagentic/saves/<save_id>/` | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_media_config_store.gd` | done |
| M4 | Send log | Upload-from-chat appends to a per-save send log; Settings can view records | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_media_send_log.gd` | done |

## PRD Trace

- REQ-013, REQ-014, REQ-015, REQ-016

PRD: `docs/prd/2026-02-04-vr-offices-multimedia-messages.md`

## Plan Index

- `docs/plan/v54-settings-media-config-and-send-log.md`

## Evidence

- 2026-02-04: `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_ui_settings_button_label.gd` → PASS
- 2026-02-04: `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_settings_overlay_has_media_tab.gd` → PASS
- 2026-02-04: `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_media_config_store.gd` → PASS
- 2026-02-04: `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_media_send_log.gd` → PASS
