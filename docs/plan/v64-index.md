# v64 index

Goal: allow installing skills from GitHub subdirectory URLs (`/tree/<ref>/<subdir>`), including `master` branch links, by downloading the repo ZIP and installing only from the specified subdir.

## Artifacts

- PRD: `docs/prd/2026-02-05-vr-offices-skill-install-github-subdir.md`
- Plan: `docs/plan/v64-vr-offices-skill-install-github-subdir.md`

## Evidence

- 2026-02-05
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_install_tree_subdir_scopes_install.gd` PASS
  - `scripts/run_godot_tests.sh --suite openagentic` PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` PASS
