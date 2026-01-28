#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ZIP_PATH="${1:-$ROOT_DIR/kenney_roguelike-characters.zip}"
OUT_DIR="${2:-$ROOT_DIR/assets/kenney/roguelike-characters}"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing zip: $ZIP_PATH" >&2
  echo "Usage: scripts/import_kenney_roguelike_characters.sh [zip_path] [out_dir]" >&2
  exit 2
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "Missing dependency: unzip" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"

echo "Extracting to: $OUT_DIR"
unzip -o "$ZIP_PATH" -d "$OUT_DIR" >/dev/null

echo "Done. You can delete the zip (it's gitignored): $ZIP_PATH"

