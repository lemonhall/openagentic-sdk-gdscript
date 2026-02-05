# v62 index

Goal: add per-save HTTP(S) proxy settings for GitHub skill ZIP downloads, without affecting any other HTTP calls.

## Artifacts

- PRD: `docs/prd/2026-02-05-vr-offices-github-download-proxy.md`
- Plan: `docs/plan/v62-vr-offices-github-download-proxy.md`

## Evidence

- 2026-02-05
  - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_skillsmp_config_store.gd` PASS
  - `scripts/run_godot_tests.sh --suite openagentic` PASS
  - `scripts/run_godot_tests.sh --suite vr_offices` PASS
