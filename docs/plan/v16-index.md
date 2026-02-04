# v16 Index — Tavily WebSearch Config in Settings Overlay

## Vision (v16)

Players/devs can configure Tavily WebSearch from inside the game:

- A **Tavily** tab exists in the settings overlay (SettingsOverlay).
- Users can set:
  - Tavily API base URL (default `https://api.tavily.com`)
  - Tavily API key
- A **Test** button validates config.
- The WebSearch tool uses the saved config (per save slot), so NPCs can search without external env setup.

## Milestones (facts panel)

1. **Plan:** write an executable v16 plan with tests. (done)
2. **UI:** add Tavily tab + wide textboxes + buttons. (done)
3. **Persistence:** save/load Tavily config per save slot. (done)
4. **Tool wiring:** WebSearch uses base URL + saved API key. (done)
5. **Verify:** run headless tests. (done)

## Plans (v16)

- `docs/plan/v16-vr-offices-tavily-settings.md`

## Definition of Done (DoD)

- `vr_offices/ui/SettingsOverlay.tscn` contains a `Tavily` tab with:
  - Base URL edit (`custom_minimum_size.x >= 520`)
  - API key edit (`custom_minimum_size.x >= 520`)
  - Save / Reload / Test buttons
- Tavily config persists under `user://openagentic/saves/<save_id>/shared/tavily_config.json`.
- `addons/openagentic/tools/OAWebTools.gd` uses Tavily base URL override (ctx/env) instead of hardcoding.
- Tests cover:
  - Tavily tab exists + fields are wide enough
  - Tavily config store save/load roundtrip

## Verification

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_settings_overlay_has_tavily_tab.gd`
- `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_tavily_config_store.gd`
- `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_tool_websearch.gd`
