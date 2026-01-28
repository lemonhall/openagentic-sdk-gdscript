#!/usr/bin/env python3

import argparse
import colorsys
import math
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
    return int(
        math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)
    )


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
        # The town heuristic is implemented as a *connected component* flood fill in
        # `generate_mask()` (because palette-only classification mislabels buildings).
        # Keep this code path unreachable so mistakes are obvious.
        raise RuntimeError("town heuristic must be handled by generate_mask()")

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

    if cfg.heuristic == "town":
        out = _generate_mask_town(img, pal_img, palette, entries, cfg)
    else:
        walkable = _select_walkable_palette(entries, palette, cfg)
        out = _mask_from_walkable_palette(pal_img, walkable, cfg)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(out_path)


def _mask_from_walkable_palette(pal_img: Image.Image, walkable: set[int], cfg: Config) -> Image.Image:
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
    return out


def _generate_mask_town(img_rgba: Image.Image, pal_img: Image.Image, palette, entries, cfg: Config) -> Image.Image:
    """
    Town heuristic:
      - quantize to palette
      - auto-pick 2 seed pixels (grass + road) from the *original* image using HSV
      - flood fill connected pixels whose palette indices look like grass/road
      - everything else becomes obstacle

    This avoids misclassifying buildings that share similar hues with roads.
    """

    def pal_rgb(i):
        return tuple(palette[i * 3 : i * 3 + 3])

    # Auto-pick grass seed: scan from top-left for a grass-ish pixel.
    img_px = img_rgba.convert("RGB").load()
    w, h = pal_img.size
    grass_seed = None
    for y in range(0, min(h, 200)):
        for x in range(0, min(w, 300)):
            c = img_px[x, y]
            if _is_grass(c) and not _is_water(c):
                grass_seed = (x, y)
                break
        if grass_seed:
            break
    if grass_seed is None:
        grass_seed = (0, 0)

    # Auto-pick road seed: scan a right-side band for a road-ish pixel.
    road_seed = None
    for y in range(0, h):
        for x in range(int(w * 0.62), int(w * 0.95)):
            c = img_px[x, y]
            if _is_road(c) and not _is_water(c) and not _is_grass(c):
                road_seed = (x, y)
                break
        if road_seed:
            break
    if road_seed is None:
        # Fallback: scan whole image.
        for y in range(h):
            for x in range(w):
                c = img_px[x, y]
                if _is_road(c) and not _is_water(c) and not _is_grass(c):
                    road_seed = (x, y)
                    break
            if road_seed:
                break

    idxs = pal_img.load()

    # Grass palette indices: all palette entries that look grass-ish.
    grass_allowed = {i for i, _count in entries if _is_grass(pal_rgb(i)) and not _is_water(pal_rgb(i))}

    # Road palette indices: road-ish entries near the road seed palette color.
    road_allowed = set()
    if road_seed is not None:
        rx, ry = road_seed
        road_seed_idx = idxs[rx, ry]
        road_seed_rgb = pal_rgb(road_seed_idx)
        # Use cfg.similar_threshold as "road palette radius" (smaller = fewer false positives).
        for i, _count in entries:
            c = pal_rgb(i)
            if _is_road(c) and not _is_water(c):
                if cfg.similar_threshold <= 0 or _rgb_dist(c, road_seed_rgb) <= cfg.similar_threshold:
                    road_allowed.add(i)

    walkable = set()
    if grass_seed and grass_allowed:
        walkable |= _flood_fill_allowed(idxs, w, h, grass_seed, grass_allowed)
    if road_seed and road_allowed:
        walkable |= _flood_fill_allowed(idxs, w, h, road_seed, road_allowed)

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out_px = out.load()
    for y in range(h):
        for x in range(w):
            is_walk = (x, y) in walkable
            if cfg.invert:
                is_walk = not is_walk
            if not is_walk:
                out_px[x, y] = (255, 255, 255, 255)
    return out


def _flood_fill_allowed(idxs, w: int, h: int, seed_xy, allowed_idxs: set[int]) -> set[tuple[int, int]]:
    sx, sy = seed_xy
    if sx < 0 or sy < 0 or sx >= w or sy >= h:
        return set()
    if idxs[sx, sy] not in allowed_idxs:
        return set()

    seen = set()
    stack = [(sx, sy)]
    seen.add((sx, sy))
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if nx < 0 or ny < 0 or nx >= w or ny >= h:
                continue
            if (nx, ny) in seen:
                continue
            if idxs[nx, ny] not in allowed_idxs:
                continue
            seen.add((nx, ny))
            stack.append((nx, ny))
    return seen


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
        default=20,
        help="Heuristic-dependent RGB distance threshold (town: road palette radius)",
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
