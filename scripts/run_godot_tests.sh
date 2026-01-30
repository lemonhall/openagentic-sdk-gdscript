#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEFAULT_GODOT_DIR_LINUX="/mnt/e/Godot_v4.6-stable_win64.exe"
DEFAULT_GODOT_EXE_LINUX="${DEFAULT_GODOT_DIR_LINUX}/Godot_v4.6-stable_win64_console.exe"

usage() {
  cat <<'EOF'
Run Godot headless test scripts from WSL2 using a Windows Godot executable.

Usage:
  scripts/run_godot_tests.sh [--exe <linux-path-to-godot-exe>] [--suite <name>] [--one <test_script.gd>] [--timeout <seconds>]

Examples:
  scripts/run_godot_tests.sh
  scripts/run_godot_tests.sh --exe "/mnt/e/Godot_v4.6-stable_win64.exe/Godot_v4.6-stable_win64_console.exe"
  scripts/run_godot_tests.sh --suite openagentic
  scripts/run_godot_tests.sh --suite vr_offices
  scripts/run_godot_tests.sh --one tests/addons/openagentic/test_sse_parser.gd
  scripts/run_godot_tests.sh --timeout 120

Suites:
  all (default), openagentic, irc_client, vr_offices, demo, demo_irc, demo_rpg, addons, projects

Notes:
  - This uses WSL interop to run a Windows .exe, and may require elevated permissions in some sandboxes.
  - The project path and script paths are converted to Windows paths using wslpath.
EOF
}

GODOT_EXE="${GODOT_WIN_EXE:-$DEFAULT_GODOT_EXE_LINUX}"
SUITE="all"
ONE=""
TIMEOUT_SEC="${GODOT_TEST_TIMEOUT_SEC:-120}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --exe)
      GODOT_EXE="$2"
      shift 2
      ;;
    --suite)
      SUITE="$2"
      shift 2
      ;;
    --one)
      ONE="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SEC="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$GODOT_EXE" ]]; then
  echo "Godot exe not found: $GODOT_EXE" >&2
  echo "Set GODOT_WIN_EXE or pass --exe." >&2
  exit 2
fi

run_with_timeout() {
  local sec="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "${sec}s" "$@"
  else
    "$@"
  fi
}

proj_win="$(wslpath -w "$ROOT_DIR")"

tests=(
  # Filled below (auto-discovery). Kept as a variable for `--one` override.
)

if [[ -n "$ONE" ]]; then
  tests=("$ONE")
else
  suite_root="tests"
  case "$SUITE" in
    all)
      suite_root="tests"
      ;;
    addons)
      suite_root="tests/addons"
      ;;
    projects)
      suite_root="tests/projects"
      ;;
    openagentic)
      suite_root="tests/addons/openagentic"
      ;;
    irc_client)
      suite_root="tests/addons/irc_client"
      ;;
    vr_offices)
      suite_root="tests/projects/vr_offices"
      ;;
    demo)
      suite_root="tests/projects/demo"
      ;;
    demo_irc)
      suite_root="tests/projects/demo_irc"
      ;;
    demo_rpg)
      suite_root="tests/projects/demo_rpg"
      ;;
    *)
      echo "Unknown suite: $SUITE" >&2
      echo "Valid suites: all, openagentic, irc_client, vr_offices, demo, demo_irc, demo_rpg, addons, projects" >&2
      exit 2
      ;;
  esac

  mapfile -t tests < <(find "$suite_root" -type f -name 'test_*.gd' | LC_ALL=C sort)

  if [[ ${#tests[@]} -eq 0 ]]; then
    echo "No tests found under ${suite_root}/**/test_*.gd" >&2
    exit 2
  fi
fi

status=0
for t in "${tests[@]}"; do
  script_linux="${ROOT_DIR}/${t}"
  if [[ ! -f "$script_linux" ]]; then
    echo "Missing test script: $t" >&2
    status=1
    continue
  fi
  script_win="$(wslpath -w "$script_linux")"
  echo "--- RUN $t"
  if ! run_with_timeout "$TIMEOUT_SEC" "$GODOT_EXE" --headless --path "$proj_win" --script "$script_win"; then
    status=1
  fi
done

exit "$status"
