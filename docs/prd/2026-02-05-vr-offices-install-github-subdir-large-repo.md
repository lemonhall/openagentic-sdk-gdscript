# VR Offices: Install GitHub Subdir Skills from Large Repos (PRD)

## Vision

Installing a skill from a GitHub subdirectory URL (e.g. `.../tree/main/skills/himalaya`) must work even when the repo contains thousands of files, by extracting only the requested subdirectory from the downloaded ZIP.

## Problem

GitHub ZIP downloads include the whole repository. Current unzip logic enforces safety limits (`MAX_FILES`, `MAX_UNZIPPED_BYTES`) across the entire ZIP, causing installs to fail for large repos even when the requested skill folder is small.

## Requirements

### REQ-001 — Selective unzip for subdir installs

When install `source.subdir` is present:

- Only unzip files under that subdir (including nested files).
- Apply `MAX_FILES` / `MAX_UNZIPPED_BYTES` limits to the extracted subset, not the whole repo ZIP.

### REQ-002 — E2E reproduction test (online, gated)

Add an opt-in E2E test that performs real download + install for:

- `https://github.com/openclaw/openclaw/tree/main/skills/himalaya`

The test must be gated so default suites do not require network access.

## Non-Goals

- Downloading subdirectories without fetching repo ZIP (GitHub API tree/raw fetching).
- Changing SkillsMP search behavior.

## Acceptance

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_e2e_install_github_tree_subdir_online.gd` passes when invoked with:
  - `--extra-args --oa-online-tests --oa-github-proxy-http=http://127.0.0.1:7897 --oa-github-proxy-https=http://127.0.0.1:7897`
- `scripts/run_godot_tests.sh --suite openagentic` passes.
- `scripts/run_godot_tests.sh --suite vr_offices` passes.

