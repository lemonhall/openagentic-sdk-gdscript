<!--
  v38 — Test suites: folder grouping + selective runner
-->

# v38 — Test Suites: Folder Grouping + Selective Runner

## Vision (this version)

- `tests/` is grouped by **addon** vs **project** (no flat pile of `test_*.gd`).
- Test runners discover tests recursively under `tests/**/test_*.gd`.
- Runners support `--suite <name>` so app-layer changes can skip core addon tests (and vice versa).

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Suite layout | Move `tests/test_*.gd` into `tests/addons/**` and `tests/projects/**` (keep `tests/_test_util.gd` at root) | `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_sse_parser.gd` | done |
| M2 | Selective runner | Update `scripts/run_godot_tests.sh` + `scripts/run_godot_tests.ps1` to support `--suite` and recursive discovery | `scripts/run_godot_tests.sh --suite openagentic` | done |

## Plan Index

- `docs/plan/v38-tests-suites.md`

## Evidence

Red (expected): after moving tests, old discovery (`tests/test_*.gd`) no longer matches:

- `scripts/run_godot_tests.sh --exe /bin/true` → `No tests found under tests/test_*.gd`

Green (Linux Godot 4.6 headless):

- `res://tests/addons/openagentic/test_sse_parser.gd` (PASS)
- `res://tests/addons/irc_client/test_irc_parser.gd` (PASS)
- `res://tests/projects/vr_offices/test_vr_offices_smoke.gd` (PASS)
- `res://tests/projects/demo_irc/test_demo_irc_smoke.gd` (PASS)
- `res://tests/projects/demo_rpg/test_demo_rpg_smoke.gd` (PASS)
