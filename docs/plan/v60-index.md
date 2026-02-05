# v60 index

Goal: make `VendingMachineOverlay` actually browse SkillsMP via API (search + pagination) and add a per-save API key settings dialog with a connectivity test button.

## Artifacts

- PRD: `docs/prd/2026-02-05-vr-offices-vending-machine-skillsmp.md`
- Plan: `docs/plan/v60-vr-offices-vending-machine-skillsmp-search.md`

## Evidence

- (2026-02-05) `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_skillsmp_config_store.gd` (PASS)
- (2026-02-05) `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_skillsmp_client_url_and_parse.gd` (PASS)
- (2026-02-05) `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_renders_stubbed_search.gd` (PASS)
- (2026-02-05) `scripts/run_godot_tests.sh --suite openagentic` (PASS)
- (2026-02-05) `scripts/run_godot_tests.sh --suite vr_offices` (PASS)
