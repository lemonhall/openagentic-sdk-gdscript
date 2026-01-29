#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ZIP_PATH="${ROOT_DIR}/kenney_mini-characters.zip"
DEST_DIR="${ROOT_DIR}/assets/kenney/mini-characters-1"
TEX_DIR="${DEST_DIR}/Textures"

if [[ ! -f "${ZIP_PATH}" ]]; then
  echo "Missing ${ZIP_PATH}"
  echo "Download: https://kenney.nl/assets/mini-characters-1"
  echo "Then place it at the repo root as: kenney_mini-characters.zip"
  exit 1
fi

mkdir -p "${DEST_DIR}" "${TEX_DIR}"

extract_one() {
  local src="$1"
  local dst="$2"
  if [[ -f "${dst}" ]]; then
    return 0
  fi
  echo "Extracting ${src} -> ${dst#${ROOT_DIR}/}"
  unzip -p "${ZIP_PATH}" "${src}" > "${dst}"
}

extract_one "License.txt" "${DEST_DIR}/License.txt"
# Keep both locations:
# - Some pipelines reference `Textures/colormap.png` relative to the .glb file.
# - Keeping a copy at the root helps if the reference is just `colormap.png`.
extract_one "Models/GLB format/Textures/colormap.png" "${TEX_DIR}/colormap.png"
extract_one "Models/GLB format/Textures/colormap.png" "${DEST_DIR}/colormap.png"

for name in \
  character-female-a \
  character-female-b \
  character-female-c \
  character-female-d \
  character-female-e \
  character-female-f \
  character-male-a \
  character-male-b \
  character-male-c \
  character-male-d \
  character-male-e \
  character-male-f
do
  extract_one "Models/GLB format/${name}.glb" "${DEST_DIR}/${name}.glb"
done

echo "Done. Assets in: ${DEST_DIR#${ROOT_DIR}/}"
