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

It creates a **draft** obstacle mask from a background image using a simple heuristic:

1. Quantize the background into a small palette (`--colors`)
2. Take the most frequent palette colors as “walkable” seeds (`--walkable-top-k`)
3. Also treat colors close to the most frequent color as walkable (`--similar-threshold`)
4. Anything not classified as walkable becomes **opaque** in the output mask (obstacle)

Command:

```bash
python3 scripts/generate_collision_mask.py <background.png> --out <mask.png>
```

Useful knobs:

- `--heuristic town|simple`:
  - `town` (default): tries to treat grass + road as walkable and water as obstacle
  - `simple`: only expands around the most frequent color (often fails to include roads)
- `--colors 16|32|64`: more colors can separate road/grass/water better
- `--similar-threshold X`: include more “nearby” colors as walkable (can accidentally include water/buildings)
- `--invert`: swap meaning (rarely useful; mostly for debugging)

---

## 4) Why roads can become “unwalkable” (and what to do)

This generator is intentionally naive: it does **not** understand “roads” or “houses”.
If the road color isn’t part of the walkable seed set, it will be treated as obstacle.

Recommended workflow:

1. **Generate a draft** mask with the script.
2. **Open the mask** in an editor (Aseprite / Krita / Photoshop / GIMP).
3. **Erase** the road area (make it transparent), and **paint** obstacles opaque.

If you want to improve the automatic draft later, a good next step is letting the generator accept:

- explicit “walkable color” overrides (picked from the background)
- or a second “walkable seed” image / scribble input

---

## 5) Debug tips

- If collisions don’t line up visually, check:
  - background `Sprite2D.centered`
  - background `Sprite2D.scale`
  - `Collision.sprite_path` points to the background sprite
- If polygons are too jagged / too heavy:
  - increase `epsilon` in `Ground/Collision`
  - simplify the mask (paint cleaner shapes)
