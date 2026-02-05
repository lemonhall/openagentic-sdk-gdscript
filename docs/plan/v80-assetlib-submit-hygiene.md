# v80 — Asset Library submission hygiene

## Goal

Bring the repo into alignment with key Godot Asset Library submission requirements/recommendations:

- license file correctness for review
- screenshots organized and not imported by Godot
- addon folder contains README + LICENSE copy
- optional git export hygiene for downloadable ZIPs

## Scope

- Screenshots:
  - Move `screenshot.png` / `screenshot2.png` into `screenshots/`
  - Add `screenshots/.gdignore`
  - Update `README.md` + `README.zh-CN.md` image links
  - Add a square icon file at `screenshots/icon.png` for AssetLib submission use
- Licensing:
  - Ensure root `LICENSE` (Apache-2.0) includes an explicit copyright statement
  - Copy license into `addons/openagentic/LICENSE` so users copying only the addon keep license text
- Git export hygiene:
  - Add `.gitattributes` to normalize line endings
  - Use `export-ignore` for dev-only local ZIPs if they are tracked

## Non-goals

- Publishing the asset entry (web form submission)
- Changing runtime behavior
- Adding an editor plugin UI (`plugin.cfg`)

## Acceptance

- `LICENSE` exists and includes:
  - Apache License 2.0 text
  - a concrete copyright statement with year(s) + holder
- `README.md` and `README.zh-CN.md` render screenshots from `screenshots/`
- `screenshots/` includes `.gdignore` and images are not imported by Godot
- `addons/openagentic/LICENSE` exists
- `.gitattributes` exists and provides safe defaults

## Files

- Add:
  - `screenshots/.gdignore`
  - `screenshots/icon.png`
  - `.gitattributes`
  - `docs/plan/v80-index.md`
  - `docs/plan/v80-assetlib-submit-hygiene.md`
- Update:
  - `README.md`
  - `README.zh-CN.md`
  - `LICENSE`

## Verification / Evidence

- `rg -n "screenshots/screenshot2\\.png|screenshots/screenshot\\.png" README.md README.zh-CN.md`
- `rg -n "Copyright 20\\d\\d" LICENSE`
- `ls -la screenshots/.gdignore addons/openagentic/LICENSE .gitattributes`
