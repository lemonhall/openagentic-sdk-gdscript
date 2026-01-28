#!/usr/bin/env python3

import argparse
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


@dataclass(frozen=True)
class Config:
    colors: int
    walkable_top_k: int
    similar_threshold: int
    invert: bool


def _rgb_dist(a, b) -> int:
    return int(((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5)


def generate_mask(background_path: Path, out_path: Path, cfg: Config) -> None:
    img = Image.open(background_path).convert("RGBA")

    # Quantize to a small palette so we can pick a "ground" color by frequency.
    pal_img = img.convert("P", palette=Image.ADAPTIVE, colors=cfg.colors)
    hist = pal_img.histogram()
    palette = pal_img.getpalette()  # list[int], len = 768

    # Find palette entries with pixels.
    entries = [(i, hist[i]) for i in range(cfg.colors) if hist[i] > 0]
    entries.sort(key=lambda t: t[1], reverse=True)
    if not entries:
        raise RuntimeError("no palette entries found")

    walkable = set(i for i, _ in entries[: cfg.walkable_top_k])
    ground_idx = entries[0][0]
    ground_rgb = tuple(palette[ground_idx * 3 : ground_idx * 3 + 3])

    # Expand walkable by RGB distance to ground.
    for idx, _count in entries:
        rgb = tuple(palette[idx * 3 : idx * 3 + 3])
        if _rgb_dist(rgb, ground_rgb) <= cfg.similar_threshold:
            walkable.add(idx)

    # Build mask where obstacles are opaque (alpha=255) and walkable is transparent.
    idxs = pal_img.load()
    w, h = pal_img.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out_px = out.load()

    for y in range(h):
        for x in range(w):
            is_walk = idxs[x, y] in walkable
            if cfg.invert:
                is_walk = not is_walk
            if not is_walk:
                out_px[x, y] = (255, 255, 255, 255)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(out_path)


def main() -> None:
    ap = argparse.ArgumentParser(description="Generate a draft collision mask from a background image.")
    ap.add_argument("background", type=Path, help="Path to background image (png recommended)")
    ap.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Output mask path (default: <background>_collision_mask.png)",
    )
    ap.add_argument("--colors", type=int, default=16, help="Palette size used for quantization")
    ap.add_argument("--walkable-top-k", type=int, default=2, help="Treat top-K most frequent colors as walkable")
    ap.add_argument(
        "--similar-threshold",
        type=int,
        default=35,
        help="Also treat colors within this RGB distance from the most frequent color as walkable",
    )
    ap.add_argument("--invert", action="store_true", help="Invert walkable vs obstacle classification")
    args = ap.parse_args()

    out = args.out
    if out is None:
        out = args.background.with_name(args.background.stem + "_collision_mask.png")

    cfg = Config(
        colors=args.colors,
        walkable_top_k=args.walkable_top_k,
        similar_threshold=args.similar_threshold,
        invert=bool(args.invert),
    )

    generate_mask(args.background, out, cfg)
    print(str(out))


if __name__ == "__main__":
    main()

