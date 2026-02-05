# v62 Plan — VR Offices: GitHub Skill ZIP Download Proxy

## Goal

Add proxy settings to `VendingMachineOverlay` settings and apply them **only** to GitHub ZIP download requests used during skill installation.

## PRD Trace

- REQ-001 Proxy fields in settings
- REQ-002 Persist proxy per save slot
- REQ-003 Apply proxy only to GitHub downloads
- REQ-004 Error handling

## Acceptance (hard DoD)

- `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_skillsmp_config_store.gd` passes (extended to assert proxy fields persist).
- `scripts/run_godot_tests.sh --suite openagentic` passes.
- `scripts/run_godot_tests.sh --suite vr_offices` passes.

## Files

- Modify:
  - `addons/openagentic/core/OASkillsMpConfig.gd` (env defaults for proxy, optional)
  - `addons/openagentic/core/OASkillsMpConfigStore.gd` (load/save proxy fields)
  - `vr_offices/ui/VendingMachineOverlay.tscn` (settings UI fields)
  - `vr_offices/ui/VendingMachineOverlay.gd` (load/save + pass proxy into GitHub download)
  - `vr_offices/core/skill_library/VrOfficesGitHubZipSource.gd` (apply proxy for network requests)
  - `tests/addons/openagentic/test_skillsmp_config_store.gd` (assert proxy persisted)

## Steps (塔山开发循环)

### 1) TDD Red

1. Update `tests/addons/openagentic/test_skillsmp_config_store.gd` to save config including `proxy_http` / `proxy_https`, then load and assert values are present.
2. Run:
   - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_skillsmp_config_store.gd`
   - Expect FAIL (proxy fields not persisted yet).

### 2) TDD Green

1. Extend `OASkillsMpConfigStore` to load/save proxy fields.
2. Update `VendingMachineOverlay` settings popup UI to include proxy edits with defaults.
3. Update GitHub ZIP download path to use proxy config only for those requests.
4. Rerun:
   - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_skillsmp_config_store.gd` (PASS)

### 3) Verify

- `scripts/run_godot_tests.sh --suite openagentic`
- `scripts/run_godot_tests.sh --suite vr_offices`

### 4) Review

- Paste PASS evidence into `docs/plan/v62-index.md`.

