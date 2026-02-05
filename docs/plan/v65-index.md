# v65 index

Goal: make installs from GitHub subdirectory URLs work for large repos by selectively unzipping only the requested subdir; add an opt-in E2E online install test for openclaw/himalaya.

## Artifacts

- PRD: `docs/prd/2026-02-05-vr-offices-install-github-subdir-large-repo.md`
- Plan: `docs/plan/v65-vr-offices-install-github-subdir-large-repo.md`

## Evidence

- 2026-02-05
  - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_e2e_install_github_tree_subdir_online.gd --extra-args --oa-online-tests --oa-github-proxy-http=http://127.0.0.1:7897 --oa-github-proxy-https=http://127.0.0.1:7897` PASS
  - `scripts/run_godot_tests.sh --suite openagentic` PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` PASS
