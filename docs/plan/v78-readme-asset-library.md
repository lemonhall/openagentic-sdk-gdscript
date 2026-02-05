# v78 — README refresh for Godot Asset Library

## Goal

Make the root README(s) usable as a “landing page” when publishing to the Godot Asset Library:

- show updated screenshots
- explain what this repo contains (Agent SDK + IRC demo + multiple playable demos)
- keep English + Chinese README content aligned

## Scope

- Update `README.md` and `README.zh-CN.md`
  - add `screenshot2.png` to the top hero area
  - add a dedicated screenshots section (keeping the older `screenshot.png`)
  - add “What’s included / 仓库内容” section
  - add a short “Using from the Godot Asset Library / 从 Godot Asset Library 使用” section
  - add “Requirements / 运行环境” section
  - mention the IRC demo scene path (`res://demo_irc/Main.tscn`)
  - add a minimal license note (prompting to add a code license before publishing)

## Non-goals

- Adding `addons/*/plugin.cfg` or editor UI
- Changing any runtime behavior
- Picking a code license on behalf of the maintainer

## Acceptance

- `README.md` renders with:
  - language switch link to Chinese README
  - hero screenshot is `screenshot2.png`
  - “Screenshots” section includes `screenshot.png`
  - a concise “What’s included” overview that mentions the addon + VR Offices + IRC demo + optional local services
  - a short section that explains how to use this repo when downloaded via the Asset Library (addon-only vs demos)
- `README.zh-CN.md` mirrors the same information and references the same screenshots/paths
- No changes outside documentation files

## Files

- Update:
  - `README.md`
  - `README.zh-CN.md`
- Add:
  - `docs/plan/v78-index.md`
  - `docs/plan/v78-readme-asset-library.md`

## Verification / Evidence

- `rg -n "screenshot2\\.png|demo_irc/Main\\.tscn|What’s included|仓库内容" README.md README.zh-CN.md`
- Manual skim: headers + code blocks remain valid Markdown
