# VR Offices: Vending Machine SkillsMP Browser (PRD)

## Vision

When the player double-clicks the workspace vending machine, they can search a third-party “skills marketplace” (SkillsMP) API and browse results inside the existing `VendingMachineOverlay` UI, including pagination and per-save API key settings.

## Requirements

### REQ-001 — Search UI (keyword search)

- In `vr_offices/ui/VendingMachineOverlay.tscn`, the `Skills` tab contains:
  - a query input (`q`)
  - a search button
  - a results area (list/grid + details is fine)
- Pressing Enter in the query input triggers search.

### REQ-002 — Pagination

- The UI supports paging through the paginated endpoint:
  - Previous / Next (minimum)
  - Shows current page, and total pages when available from the response.
- Pagination state is scoped to the current query.

### REQ-003 — Settings: API key per save slot

- The overlay contains a Settings button (in a corner / header area).
- Clicking Settings opens a settings dialog where the user can:
  - enter an API key
  - read a hint that they must register with the vendor to generate an API key
  - save the key
- The API key is persisted **per save slot** (save_id), not globally.
- The effective config uses environment defaults, but per-save config overrides them (same pattern as Tavily settings).

### REQ-004 — Settings: test connectivity

- The settings dialog contains a `Test` button.
- `Test` performs a lightweight request to validate the API base URL + API key, and shows `OK` or a readable error.

### REQ-005 — Error handling & UX

- Missing API key shows a clear message and directs the user to Settings.
- API errors are displayed without crashing:
  - `MISSING_API_KEY` (401)
  - `INVALID_API_KEY` (401)
  - `MISSING_QUERY` (400)
  - `INTERNAL_ERROR` (500)
- UI shows a loading state while searching / testing.

## Non-Goals

- Implementing `/api/v1/skills/ai-search` (semantic search).
- Installing / importing skills into NPC workspaces.
- Caching results, offline mode, or background prefetch.
- Any changes to `demo_rpg/`.

## Data & Persistence

- Storage location (per save_id):
  - `user://openagentic/saves/<save_id>/shared/skillsmp_config.json`
- Fields:
  - `base_url` (optional, default `https://skillsmp.com`)
  - `api_key`

## API Contract (as provided)

- `GET /api/v1/skills/search?q=<string>&page=<number>&limit=<number>&sortBy=<stars|recent>`
- Auth header: `Authorization: Bearer <api-key>`
- Errors are JSON:
  - `{"success": false, "error": {"code": "...", "message": "..."}}`

## Acceptance (Definition of Done)

- Tests:
  - Config store save/load per save_id is covered by a new automated test.
  - Client URL building / response parsing is covered by a new automated test (no real network).
  - Vending overlay can render stubbed search results in a new automated test (no real network).
- Manual:
  - In VR Offices, open vending overlay → search works (with valid key) and pagination works.
  - Settings dialog: save key, test key, close/reopen overlay shows key loaded for the same save slot.

