# v38 — Test Suites (addons/ vs projects/)

## Goal

Make headless tests easy to navigate and run selectively by module:

- Core addon changes → run addon suites.
- App changes (e.g. `vr_offices/`) → run only that project suite.

## Scope

In scope:

- Move test scripts into:
  - `tests/addons/openagentic/`
  - `tests/addons/irc_client/`
  - `tests/projects/demo/`
  - `tests/projects/demo_irc/`
  - `tests/projects/demo_rpg/`
  - `tests/projects/vr_offices/`
- Keep shared helper at `tests/_test_util.gd`.
- Update runners to:
  - discover `tests/**/test_*.gd`
  - add `--suite <name>` filtering
- Update README(s) to reflect new locations and runner usage.

Out of scope:

- Renaming tests or changing test behavior.
- Changing any runtime/addon code.

## Acceptance

- `scripts/run_godot_tests.sh`:
  - finds tests recursively
  - supports `--suite openagentic|irc_client|vr_offices|demo_irc|demo_rpg|demo|all`
  - `--one <path>` still works for an explicit test file
- `scripts/run_godot_tests.ps1` matches the same behavior.
- README instructions no longer reference removed paths like `tests/test_sse_parser.gd`.

## Files

- Modify:
  - `scripts/run_godot_tests.sh`
  - `scripts/run_godot_tests.ps1`
  - `README.md`
  - `README.zh-CN.md`
- Move:
  - `tests/test_*.gd` → suite folders under `tests/addons/**` and `tests/projects/**`
  - `tests/test_*.gd.uid` alongside each moved test

## Steps (塔山开发循环)

### 1) Red — break old discovery (expected failure)

1. Move a small subset of tests (plus their `.uid` files) out of `tests/` into their target suite folder.
2. Run the existing runner discovery to confirm it fails because `tests/test_*.gd` no longer matches.

Expected:

- `scripts/run_godot_tests.sh` errors with “No tests found under tests/test_*.gd”.

### 2) Green — restore discovery + add `--suite`

1. Update both runners to discover `tests/**/test_*.gd`.
2. Add `--suite` filtering (directory-based).
3. Verify:
   - `--suite openagentic` runs only tests under `tests/addons/openagentic/**`
   - `--suite vr_offices` runs only tests under `tests/projects/vr_offices/**`
   - `--suite all` runs everything under `tests/**/test_*.gd`

### 3) Refactor — docs + ergonomics

1. Update README snippets to show:
   - new explicit test paths
   - suite runner usage examples

## Verification (Linux Godot recommended)

Environment (to avoid `user://` writing issues):

```bash
export GODOT_LINUX_EXE=${GODOT_LINUX_EXE:-/home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64}
export HOME=/tmp/oa-home
export XDG_DATA_HOME=/tmp/oa-xdg-data
export XDG_CONFIG_HOME=/tmp/oa-xdg-config
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
```

Run a suite:

```bash
scripts/run_godot_tests.sh --suite vr_offices
```

Run one test:

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/addons/openagentic/test_sse_parser.gd
```

