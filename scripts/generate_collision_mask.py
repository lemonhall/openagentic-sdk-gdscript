#!/usr/bin/env python3

import argparse
import colorsys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


@dataclass(frozen=True)
class Config:
    heuristic: str
    colors: int
    similar_threshold: int
    invert: bool


def _rgb_dist(a, b) -> int:
    return int(((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5)


def _rgb_to_hsv(rgb):
    r, g, b = [c / 255.0 for c in rgb]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return h * 360.0, s, v


def _is_water(rgb) -> bool:
    h, s, v = _rgb_to_hsv(rgb)
    return 160.0 <= h <= 220.0 and s >= 0.15 and v >= 0.30


def _is_grass(rgb) -> bool:
    h, s, v = _rgb_to_hsv(rgb)
    return 65.0 <= h <= 170.0 and s >= 0.20 and v >= 0.25


def _is_road(rgb) -> bool:
    h, s, v = _rgb_to_hsv(rgb)
    # Brown-ish, moderately saturated, not too dark/bright.
    return 10.0 <= h <= 55.0 and s >= 0.15 and 0.25 <= v <= 0.90


def _is_building_like(rgb) -> bool:
    # Near-white / grey-ish tiles (walls/stone) often show up as large regions.
    r, g, b = rgb
    if r + g + b >= 720:
        return True
    h, s, v = _rgb_to_hsv(rgb)
    return s <= 0.12 and v >= 0.70


def _select_walkable_palette(entries, palette, cfg: Config):
    def rgb(idx):
        return tuple(palette[idx * 3 : idx * 3 + 3])

    if cfg.heuristic == "simple":
        # Back-compat: treat the single most frequent color as walkable seed and expand by distance.
        entries_sorted = sorted(entries, key=lambda t: t[1], reverse=True)
        seed = entries_sorted[0][0]
        seed_rgb = rgb(seed)
        walkable = {seed}
        for idx, _count in entries_sorted:
            if _rgb_dist(rgb(idx), seed_rgb) <= cfg.similar_threshold:
                walkable.add(idx)
        return walkable

    if cfg.heuristic == "town":
        entries_sorted = sorted(entries, key=lambda t: t[1], reverse=True)
        walkable = set()

        # Seed with obvious grass/road colors; exclude water.
        for idx, _count in entries_sorted:
            c = rgb(idx)
            if _is_water(c):
                continue
            if _is_grass(c) or _is_road(c):
                walkable.add(idx)

        # Ensure we always include the most frequent non-water color as a baseline.
        for idx, _count in entries_sorted:
            c = rgb(idx)
            if not _is_water(c):
                walkable.add(idx)
                break

        # Expand by distance to selected walkable colors, while still excluding water/building-like.
        if cfg.similar_threshold > 0 and walkable:
            seeds = [rgb(i) for i in walkable]
            for idx, _count in entries_sorted:
                if idx in walkable:
                    continue
                c = rgb(idx)
                if _is_water(c) or _is_building_like(c):
                    continue
                if any(_rgb_dist(c, s) <= cfg.similar_threshold for s in seeds):
                    walkable.add(idx)

        return walkable

    raise ValueError(f"unknown heuristic: {cfg.heuristic}")


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

    walkable = _select_walkable_palette(entries, palette, cfg)

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
    ap.add_argument(
        "--heuristic",
        choices=["simple", "town"],
        default="town",
        help="Classification heuristic (default: town)",
    )
    ap.add_argument("--colors", type=int, default=16, help="Palette size used for quantization")
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
        heuristic=args.heuristic,
        colors=args.colors,
        similar_threshold=args.similar_threshold,
        invert=bool(args.invert),
    )

    generate_mask(args.background, out, cfg)
    print(str(out))


if __name__ == "__main__":
    main()
