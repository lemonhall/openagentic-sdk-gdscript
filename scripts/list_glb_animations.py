#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path


def read_glb_json(path: Path) -> dict:
	data = path.read_bytes()
	if data[:4] != b"glTF":
		raise SystemExit(f"Not a .glb file: {path}")

	version, length = struct.unpack_from("<II", data, 4)
	if version != 2:
		raise SystemExit(f"Unsupported glTF version {version} in {path}")

	offset = 12
	json_chunk = None
	while offset < length:
		chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
		offset += 8
		chunk = data[offset : offset + chunk_len]
		offset += chunk_len
		if chunk_type == 0x4E4F534A:  # JSON
			json_chunk = chunk
			break

	if json_chunk is None:
		raise SystemExit(f"No JSON chunk found in {path}")

	return json.loads(json_chunk.decode("utf-8").rstrip("\x00 \t\r\n"))


def main() -> int:
	ap = argparse.ArgumentParser(description="List animation names embedded in a .glb file (no Godot required).")
	ap.add_argument("glb", type=Path, help="Path to .glb file")
	args = ap.parse_args()

	doc = read_glb_json(args.glb)
	anims = doc.get("animations", [])
	print(f"Animations ({len(anims)}):")
	for i, a in enumerate(anims):
		name = a.get("name") or f"Animation_{i}"
		print(f"- {name}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())

