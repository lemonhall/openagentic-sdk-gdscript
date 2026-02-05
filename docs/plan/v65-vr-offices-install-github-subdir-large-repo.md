# v65 Plan — VR Offices: Install GitHub Subdir Skills from Large Repos

## Goal

Avoid failing installs due to repo-wide unzip limits by extracting only the requested skill subdir when installing from GitHub `/tree/<ref>/<subdir>` URLs.

## PRD Trace

- REQ-001 Selective unzip for subdir installs
- REQ-002 E2E reproduction test (online, gated)

## Acceptance (hard DoD)

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_e2e_install_github_tree_subdir_online.gd --extra-args --oa-online-tests --oa-github-proxy-http=http://127.0.0.1:7897 --oa-github-proxy-https=http://127.0.0.1:7897` passes.
- `scripts/run_godot_tests.sh --suite openagentic` passes.
- `scripts/run_godot_tests.sh --suite vr_offices` passes.

## Files

- Modify:
  - `vr_offices/core/skill_library/VrOfficesZipUnpack.gd` (support subdir filter)
  - `vr_offices/core/skill_library/VrOfficesSkillPackInstaller.gd` (pass subdir into unzip; enforce subdir present)
- Add:
  - `tests/projects/vr_offices/test_e2e_install_github_tree_subdir_online.gd`

## Steps (塔山开发循环)

### 1) TDD Red

1. Run E2E install test against openclaw/himalaya with proxy args.
2. Expect FAIL with `TooManyFiles` while unzipping the full repo.

### 2) TDD Green

1. Implement unzip filtering so only `source.subdir` is extracted.
2. Rerun the E2E test to PASS.

### 3) Verify

- `scripts/run_godot_tests.sh --suite openagentic`
- `scripts/run_godot_tests.sh --suite vr_offices`

### 4) Review

- Paste PASS evidence into `docs/plan/v65-index.md`.

