# v16 Plan — Tavily WebSearch Config in Settings Overlay

## Goal

Add in-game configuration for Tavily WebSearch so NPCs can use `WebSearch` without requiring users to set env vars manually.

## PRD Trace

- DevEx: Provide in-game settings for Tavily base URL + API key, with a quick test action.

## Scope

**In scope**
- Add a `Tavily` tab to `vr_offices/ui/SettingsOverlay.tscn`.
- Implement save/load of Tavily config per save slot.
- Update WebSearch tool to use a configurable Tavily base URL.
- Add tests for UI presence + config store.

**Out of scope**
- Changing tool permission policy.
- Adding domain allow/block lists to UI.

## Acceptance

- Calling `WebSearch` succeeds when Tavily config is stored for the current save slot (even if env vars are unset).
- Tavily tab textboxes are wide (min width 520).
- Test suite runs headless and passes for the added tests.

## Files

- Add:
  - `addons/openagentic/core/OATavilyConfig.gd`
  - `addons/openagentic/core/OATavilyConfigStore.gd`
  - `tests/addons/openagentic/test_tavily_config_store.gd`
  - `tests/projects/vr_offices/test_vr_offices_settings_overlay_has_tavily_tab.gd`
- Update:
  - `addons/openagentic/OpenAgentic.gd`
  - `addons/openagentic/tools/OAWebTools.gd`
  - `vr_offices/ui/SettingsOverlay.gd`
  - `vr_offices/ui/SettingsOverlay.tscn`
  - `.env.example`

## Steps (Red → Green → Refactor)

1) **Red**: add failing tests:
   - Tavily tab exists in SettingsOverlay.
   - Tavily config store roundtrip.
2) **Green**: implement UI + store + wiring.
3) **Refactor**: keep naming stable; avoid hardcoding tab indices.

## Risks

- Must not run real network calls in tests; health/test button uses injectable transport if needed.
- Key is sensitive; never commit `.env` and keep `.env.example` blank for secrets.
