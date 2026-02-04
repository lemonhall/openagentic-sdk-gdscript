<!--
  v54 — plan: settings overlay media config + health + folder + send log
-->

# v54 — Settings UX Plan (Media config + health + folder + send log)

## Goal

Make media features usable without env vars:

- Rename the top-left `IRC…` button to `Settings…`.
- Add a `Media` tab to the existing overlay:
  - edit base URL + token
  - test `/healthz`
  - open player receive cache folder
  - show media send records (log only)

## PRD Trace

- REQ-013, REQ-014, REQ-015, REQ-016

PRD: `docs/prd/2026-02-04-vr-offices-multimedia-messages.md`

## Acceptance (DoD)

1) UI button shows `Settings…`.
2) Overlay contains a `Media` tab with:
   - base URL input
   - token input (masked)
   - `Test health` button which hits `GET /healthz` and shows status
   - `Open receive folder` button
   - `Send log` list with refresh
3) Media config persists per save slot under `user://openagentic/saves/<save_id>/vr_offices/media_config.json`.
4) Attachment send appends JSONL records under `user://openagentic/saves/<save_id>/vr_offices/media_sent.jsonl`.

## Files

Modify:

- `vr_offices/ui/VrOfficesUi.tscn`
- `vr_offices/ui/IrcOverlay.tscn`
- `vr_offices/ui/IrcOverlay.gd`
- `vr_offices/ui/DialogueOverlay.gd`

Add:

- `vr_offices/core/media/VrOfficesMediaConfigStore.gd`
- `vr_offices/core/media/VrOfficesMediaHealth.gd`
- `vr_offices/core/media/VrOfficesMediaSendLog.gd`
- Tests:
  - `tests/projects/vr_offices/test_vr_offices_ui_settings_button_label.gd`
  - `tests/projects/vr_offices/test_vr_offices_settings_overlay_has_media_tab.gd`
  - `tests/projects/vr_offices/test_vr_offices_media_config_store.gd`
  - `tests/projects/vr_offices/test_vr_offices_media_send_log.gd`

## Steps (TDD, RED → GREEN)

### Slice A — UI entry (button label)

1) **Red**: add `test_vr_offices_ui_settings_button_label.gd` expecting `Settings…`
2) **Verify Red**:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_ui_settings_button_label.gd
```

3) **Green**: change `vr_offices/ui/VrOfficesUi.tscn` label to `Settings…`
4) **Verify Green**: same command PASS

### Slice B — Media tab exists

1) **Red**: add `test_vr_offices_settings_overlay_has_media_tab.gd`
2) **Green**: add `Media` tab nodes in `IrcOverlay.tscn`
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_settings_overlay_has_media_tab.gd
```

### Slice C — Persistence + health check helpers

1) **Red**: add `test_vr_offices_media_config_store.gd` for save/load
2) **Green**: implement `VrOfficesMediaConfigStore.gd`
3) **Green**: implement `VrOfficesMediaHealth.gd` with injectable transport

### Slice D — Send log + wiring

1) **Red**: add `test_vr_offices_media_send_log.gd` for append/list
2) **Green**: implement `VrOfficesMediaSendLog.gd`
3) **Green**: wire into `DialogueOverlay.gd` after successful attachment send
4) **Green**: add Settings overlay UI to view list + refresh

