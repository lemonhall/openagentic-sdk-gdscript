# v61 index

Goal: build a per-save shared Skill Library (“图书馆”) for VR Offices, with clear tab responsibilities:

- Tab 1 (Search): “找 / 装 / 验” — find remote skills, show details (including GitHub repo URL), install+validate from the selected skill.
- Tab 2 (Library): “管” — manage local shared library (search/filter, list, uninstall, view details).

## Artifacts

- PRD: `docs/prd/2026-02-05-vr-offices-shared-skill-library.md`
- Plan: `docs/plan/v61-vr-offices-shared-skill-library.md`

## Evidence

- (2026-02-05) `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_skill_md_validator.gd` (PASS)
- (2026-02-05) `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_shared_skill_library_installs_zip.gd` (PASS)
- (2026-02-05) `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_search_tab_install_and_repo_link.gd` (PASS)
- (2026-02-05) `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_library_tab_manage_and_filter.gd` (PASS)
- (2026-02-05) `scripts/run_godot_tests.sh --suite vr_offices` (PASS)

## Notes

- `doc_hygiene_check.py` currently reports many legacy `docs/plan/v*` files missing PRD Trace; `v61-*` plan docs include PRD Trace and are written in the new style.
