# Collision Masks (Auto Draft → Runtime Colliders)

This repo supports a “painted background map” workflow where collisions are generated from a PNG **mask**:

- **Mask transparent** (alpha = 0): walkable
- **Mask opaque** (alpha > 0): obstacle

The mask is intended to be a **draft** you can quickly touch up (erase roads / add walls), then collisions are rebuilt automatically.

---

## 1) Files involved

- Background image (example): `assets/kenney/roguelike-rpg-pack/Sample1.png`
- Draft mask (example): `demo_rpg/collision/sample1_collision_mask.png`
- Runtime collider builder: `demo_rpg/collision/OACollisionFromMask.gd`
- Headless test: `tests/test_collision_from_mask.gd`
- Mask quality regression test: `tests/test_collision_mask_quality.gd`

In the RPG demo, the collision node is wired in `demo_rpg/World.tscn` under `Ground/Collision`.

---

## 2) How the runtime collider works (Godot)

`OACollisionFromMask.gd` does:

1. Load mask image from `mask_path`
2. Build a `BitMap` from mask alpha (`BitMap.create_from_image_alpha`)
3. Convert opaque regions into polygons (`BitMap.opaque_to_polygons(rect, epsilon)`)
4. Create `StaticBody2D` + `CollisionPolygon2D` children for each polygon
5. Align collision space to the background `Sprite2D` via `sprite_path`:
   - `position` is set to the background’s top-left (when `centered = true`)
   - `scale` is copied from the background sprite

**Notes**

- `epsilon` controls polygon simplification: larger = fewer points but less accurate.
- This is runtime-safe (works after export). For performance on large masks, consider caching polygons later.

---

## 3) How the draft mask is generated (Python)

Generator script: `scripts/generate_collision_mask.py` (default heuristic: `town`)

It creates a **draft** obstacle mask from a background image using a heuristic.

### Heuristic: `town` (default)

For the Kenney sample-town style background, the generator:

1. Quantizes the background into a palette (`--colors`)
2. Auto-picks **grass** and **road** seed pixels from the original image (HSV rules)
3. Flood-fills connected pixels whose **palette indices** look like grass/road
4. Everything else becomes **opaque** in the output mask (obstacle)

This keeps “house walls” from becoming walkable even when their colors are similar to roads.

Command:

```bash
python3 scripts/generate_collision_mask.py <background.png> --out <mask.png>
```

Useful knobs:

- `--heuristic town|simple`:
  - `town` (default): connected-component flood fill from grass+road seeds (better for towns)
  - `simple`: expands around the most frequent color (often fails to include roads)
- `--colors 16|32|64`: more colors can separate road/grass/water better
- `--similar-threshold X`:
  - `town`: road palette radius (smaller = fewer false positives, but can miss shaded road pixels)
  - `simple`: expands around the most frequent color
- `--grass-radius X` (`town`): how far from the grass seed palette color to allow (smaller reduces “accidental walkable foliage”)
- `--grass-seed x,y` / `--road-seed x,y` (`town`): override the auto-picked seed pixels when the scan picks a bad spot
- `--invert`: swap meaning (rarely useful; mostly for debugging)

---

## 4) Why roads can become “unwalkable” (and what to do)

This generator is intentionally heuristic-based: it does **not** truly “understand” roads/houses.
If the auto-picked road seed lands on the wrong pixel (or the palette radius is too tight), roads can be treated as obstacle.

Recommended workflow:

1. **Regenerate** with a slightly larger road radius: `--similar-threshold 25` (or smaller if it leaks into buildings).
2. If the scan picked a bad seed, **override**: `--road-seed x,y` (pick any road pixel).
3. As a last resort, **touch up** the draft in an image editor (erase roads / paint walls).

If you want to improve the automatic draft later, good next steps include:

- explicit “walkable color” overrides (picked from the background)
- an extra “scribble seed” mask as a hint layer
- a vision-model segmentation pass (offline/dev-time) to propose obstacles

For the RPG demo, this repo ships a pre-generated mask at `demo_rpg/collision/sample1_collision_mask.png` so you can play immediately without running the generator.

---

## 5) Debug tips

- If collisions don’t line up visually, check:
  - background `Sprite2D.centered`
  - background `Sprite2D.scale`
  - `Collision.sprite_path` points to the background sprite
- If polygons are too jagged / too heavy:
  - increase `epsilon` in `Ground/Collision`
  - simplify the mask (paint cleaner shapes)
