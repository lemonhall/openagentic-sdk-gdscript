# v60 Plan — VR Offices: Vending Machine SkillsMP Search + Settings

## Goal

Implement a simple in-overlay SkillsMP browser:

- Search (`GET /api/v1/skills/search`) with query input + button.
- Pagination (prev/next) for paginated responses.
- Settings dialog to store API key per save slot, with a `Test` button to validate connectivity.

## PRD Trace

- REQ-001 Search UI
- REQ-002 Pagination
- REQ-003 Settings per save slot
- REQ-004 Settings connectivity test
- REQ-005 Error handling

## Scope

- Add a SkillsMP config store (per-save) matching the established Tavily pattern.
- Add a small SkillsMP API client using `OAMediaHttp` (supports transport override for tests).
- Upgrade `VendingMachineOverlay` UI to:
  - include search controls + results rendering
  - include pagination controls
  - include a Settings popup with API key save + test

## Non-Goals

- No AI search endpoint.
- No skill installation/import workflow.
- No caching or offline mode.

## Acceptance (hard DoD)

- `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_skillsmp_config_store.gd` passes.
- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_skillsmp_client_url_and_parse.gd` passes.
- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_renders_stubbed_search.gd` passes.
- `scripts/run_godot_tests.sh --suite vr_offices` passes.
- `scripts/run_godot_tests.sh --suite openagentic` passes.

Anti-cheat clause:
- Tests must stub transport (no real network) and assert rendered UI state (not just “no crash”).

## Files

- Add:
  - `addons/openagentic/core/OASkillsMpConfig.gd`
  - `addons/openagentic/core/OASkillsMpConfigStore.gd`
  - `vr_offices/core/skillsmp/VrOfficesSkillsMpClient.gd`
  - `vr_offices/core/skillsmp/VrOfficesSkillsMpHealth.gd`
  - `tests/addons/openagentic/test_skillsmp_config_store.gd`
  - `tests/projects/vr_offices/test_skillsmp_client_url_and_parse.gd`
  - `tests/projects/vr_offices/test_vending_machine_overlay_renders_stubbed_search.gd`
- Modify:
  - `vr_offices/ui/VendingMachineOverlay.tscn`
  - `vr_offices/ui/VendingMachineOverlay.gd`

## Steps (塔山开发循环)

### 1) TDD Red — config store

1. Add failing test `tests/addons/openagentic/test_skillsmp_config_store.gd`:
   - saves config for a unique save_id
   - loads it back and asserts normalized values
2. Run to confirm failure:
   - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_skillsmp_config_store.gd`
   - Expect FAIL: missing `OASkillsMpConfigStore.gd`

### 2) TDD Green — config store implementation

1. Implement `OASkillsMpConfig.gd` (env defaults) + `OASkillsMpConfigStore.gd` (save/load).
2. Rerun:
   - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_skillsmp_config_store.gd`
   - Expect PASS

### 3) TDD Red — SkillsMP client URL + parse

1. Add failing test `tests/projects/vr_offices/test_skillsmp_client_url_and_parse.gd`:
   - asserts URL building (`q`, `page`, `limit`, `sortBy`)
   - stubs transport to return a representative JSON payload and asserts parsed items + pagination fields
2. Run:
   - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_skillsmp_client_url_and_parse.gd`
   - Expect FAIL: missing client script

### 4) TDD Green — client + health check

1. Implement `VrOfficesSkillsMpClient.gd` using `OAMediaHttp.request` with transport injection.
2. Implement `VrOfficesSkillsMpHealth.gd` (`Test` button helper).
3. Rerun:
   - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_skillsmp_client_url_and_parse.gd`

### 5) TDD Red — overlay renders results

1. Add failing test `tests/projects/vr_offices/test_vending_machine_overlay_renders_stubbed_search.gd`:
   - instantiate `VendingMachineOverlay.tscn`
   - inject a stub transport that returns N skills + pagination
   - call a public method to run a search
   - assert UI renders N list rows and shows page label
2. Run:
   - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_renders_stubbed_search.gd`
   - Expect FAIL: missing UI nodes/methods

### 6) TDD Green — overlay UI + settings

1. Update `VendingMachineOverlay.tscn`:
   - add search controls
   - add results list + details
   - add pagination controls
   - add Settings button + Settings popup (API key + hint + save + test + status)
2. Update `VendingMachineOverlay.gd`:
   - wire signals
   - load/save config per save_id
   - call client search and render results
   - implement pagination controls
3. Rerun:
   - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_renders_stubbed_search.gd`
   - Expect PASS

### 7) Verify — suites

- `scripts/run_godot_tests.sh --suite openagentic`
- `scripts/run_godot_tests.sh --suite vr_offices`

### 8) Review — update evidence

- Paste PASS evidence into `docs/plan/v60-index.md`.
- Note any known gaps in `docs/plan/v60-index.md` if deferred.

