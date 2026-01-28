#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEFAULT_GODOT_DIR_LINUX="/mnt/e/Godot_v4.5.1-stable_win64.exe"
DEFAULT_GODOT_EXE_LINUX="${DEFAULT_GODOT_DIR_LINUX}/Godot_v4.5.1-stable_win64_console.exe"

usage() {
  cat <<'EOF'
Run Godot headless test scripts from WSL2 using a Windows Godot executable.

Usage:
  scripts/run_godot_tests.sh [--exe <linux-path-to-godot-exe>] [--one <test_script.gd>]

Examples:
  scripts/run_godot_tests.sh
  scripts/run_godot_tests.sh --exe "/mnt/e/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe"
  scripts/run_godot_tests.sh --one tests/test_sse_parser.gd

Notes:
  - This uses WSL interop to run a Windows .exe, and may require elevated permissions in some sandboxes.
  - The project path and script paths are converted to Windows paths using wslpath.
EOF
}

GODOT_EXE="${GODOT_WIN_EXE:-$DEFAULT_GODOT_EXE_LINUX}"
ONE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --exe)
      GODOT_EXE="$2"
      shift 2
      ;;
    --one)
      ONE="$2"
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

proj_win="$(wslpath -w "$ROOT_DIR")"

tests=(
  # Filled below (auto-discovery). Kept as a variable for `--one` override.
)

if [[ -n "$ONE" ]]; then
  tests=("$ONE")
else
  shopt -s nullglob
  tests=(tests/test_*.gd)
  shopt -u nullglob

  if [[ ${#tests[@]} -eq 0 ]]; then
    echo "No tests found under tests/test_*.gd" >&2
    exit 2
  fi

  IFS=$'\n' tests=($(printf '%s\n' "${tests[@]}" | LC_ALL=C sort))
  unset IFS
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
  if ! "$GODOT_EXE" --headless --path "$proj_win" --script "$script_win"; then
    status=1
  fi
done

exit "$status"
