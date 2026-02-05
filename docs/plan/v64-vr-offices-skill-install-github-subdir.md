# v64 Plan — VR Offices: Install Skills from GitHub Subdirectory URLs

## Goal

Support GitHub install URLs that point to repo subdirectories (e.g. `/tree/main/skills/<skill>`), including `master` branch links, by downloading ZIP for the correct ref and scoping install discovery to the requested subdir.

## PRD Trace

- REQ-001 Parse GitHub subdirectory URLs
- REQ-002 Download ZIP for specified ref
- REQ-003 Install only from requested subdir
- REQ-004 Master branch tree URLs work

## Acceptance (hard DoD)

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_install_tree_subdir_scopes_install.gd` passes.
- `scripts/run_godot_tests.sh --suite openagentic` passes.
- `scripts/run_godot_tests.sh --suite vr_offices` passes.

## Files

- Modify:
  - `vr_offices/core/skill_library/VrOfficesGitHubZipSource.gd` (parse tree/blob URLs, return `ref`/`subdir`)
  - `vr_offices/core/skill_library/VrOfficesSkillPackInstaller.gd` (scope scan root to `source.subdir` when present)
  - `vr_offices/ui/VendingMachineOverlay.gd` (include `subdir` in install `source`)
- Add:
  - `tests/projects/vr_offices/test_vending_machine_overlay_install_tree_subdir_scopes_install.gd`

## Steps (塔山开发循环)

### 1) TDD Red

1. Add failing test that:
   - selects a skill with repo URL `https://github.com/<o>/<r>/tree/master/ai/skills/skill-writer`
   - transport returns a zip containing:
     - one skill under `ai/skills/skill-writer/SKILL.md`
     - another skill elsewhere in the repo
   - asserts only the skill under the requested subdir is installed.
2. Run:
   - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_install_tree_subdir_scopes_install.gd`
   - Expect FAIL (installer currently scans entire repo zip).

### 2) TDD Green

1. Implement URL parsing in `VrOfficesGitHubZipSource`:
   - extract `owner`, `repo`, optional `ref`, optional `subdir`
   - when `ref` provided, download ZIP for that ref only
2. Extend install `source` dict to include `subdir`.
3. In `VrOfficesSkillPackInstaller.install_zip_for_save`, if `source.subdir` is present:
   - validate it is a safe relative path
   - set scan root to `<unzip_root>/<subdir>` (must exist) before discovery.
4. Rerun the test to PASS.

### 3) Verify

- `scripts/run_godot_tests.sh --suite openagentic`
- `scripts/run_godot_tests.sh --suite vr_offices`

### 4) Review

- Paste PASS evidence into `docs/plan/v64-index.md`.

