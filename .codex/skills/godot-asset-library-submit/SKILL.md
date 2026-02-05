---
name: godot-asset-library-submit
description: Use when preparing and submitting a Godot addon or demo project to the Godot Asset Library (AssetLib), especially to meet review requirements (working on the declared Godot version, proper .gitignore, no essential submodules, correct license file + listing match, correct English name/description, direct icon/preview links) and to avoid common rejection reasons.
license: Apache-2.0
compatibility: Godot Asset Library submissions (web form) + Git repository hosting (recommended: GitHub).
metadata:
  author: openagentic
  version: "1.0"
---

# Godot Asset Library submit

Turn the official Asset Library submission guidelines into a repeatable checklist with “gotchas” that commonly cause rejections.

## 0) Decide what you’re submitting (Addon vs Project)

Pick **one primary intent**; the ZIP people download must work without extra steps.

- **Addon**: users install into an existing project.
  - Put deliverables under `addons/<asset_name>/...` (avoid naming collisions).
  - If this is an *Editor Plugin*, include `addons/<asset_name>/plugin.cfg` and ensure it enables cleanly.
  - If this is a *runtime addon* (autoload, scripts, resources), a `plugin.cfg` is optional, but install docs must be clear.
- **Project / Demo / Template**: users download a full runnable project.
  - Ensure `project.godot` is included and the main scene(s) run.

**Red flags**
- “Addon” entry that requires users to manually move files around.
- Demo/project entry that only works after downloading extra content.

## 1) Hard requirements checklist (review gate)

### 1.1 The asset must work on the declared Godot version

- Validate on a clean state (fresh project or clean user data) for the version you declare.
- Prefer automated headless tests if available.

### 1.2 `.gitignore` hygiene

Ensure redundant/generated files aren’t committed (typical examples):

- `.godot/`, `.import/`, `*.import`, logs, OS junk.

### 1.3 No essential submodules

- Avoid submodules entirely.
- If submodules exist, the asset must still work without them (AssetLib ZIP downloads often omit submodule contents).

Quick checks:
```bash
git submodule status || true
```

### 1.4 License correctness (repo + listing must match)

AssetLib reviewers expect:

- A license file named `LICENSE` or `LICENSE.md`.
- It contains the **license text**.
- It contains a **copyright statement** with **year(s)** and **copyright holder**.
- The **license you select** in the AssetLib form **matches** the repo’s license file.

If you’re using Apache-2.0, ensure the repository also carries a clear copyright notice
(commonly at the top of `LICENSE`, or via a `NOTICE` file + per-file headers—follow AssetLib’s requirement for the license file itself).

### 1.5 English name + description quality

- Use proper English capitalization.
- Use full sentences in the description.
- You may include other languages, but there must be an English version.

### 1.6 Icon URL must be a *direct* link

- Must be a direct image URL (PNG/JPG), not an HTML page.
- For GitHub, use `raw.githubusercontent.com/...`, not `github.com/...`.
- Icon must be square (1:1) and at least 128×128.

Quick check (should return `Content-Type: image/...`):
```bash
curl -I "<ICON_URL>"
```

## 2) Strong recommendations (avoid paper cuts)

### 2.1 Fix or suppress script warnings

Treat warnings as “future errors” for users.

### 2.2 Screenshots: put them in a folder + add `.gdignore`

If your repo includes screenshots:

- Put them under a dedicated folder (e.g. `screenshots/`).
- Add an empty `.gdignore` file in that folder to prevent Godot from importing them.

Example:
```bash
mkdir -p screenshots
touch screenshots/.gdignore
```

### 2.3 Consider `.gitattributes` with `export-ignore`

If you ship a full repo with lots of dev-only files, `export-ignore` can keep AssetLib downloads lean.

### 2.4 If submitting an addon, include README + LICENSE *inside the addon folder too*

Users might only copy `addons/<asset_name>/...` into their projects.
Keeping `addons/<asset_name>/README.md` and `addons/<asset_name>/LICENSE` helps preserve licensing and docs.

## 3) Submission form: prep the fields

Gather these ahead of time so you can submit in one pass:

- Asset name (English), category (Addon vs Project), Godot version (e.g. 4.6), asset version
- Repository URL, Issues URL
- Download commit (exact SHA):
  ```bash
  git rev-parse HEAD
  ```
- Icon URL (direct raw image)
- Optional preview image/video URLs (direct links; keep them public)
- Plain-text description (English first; add Chinese after if desired)
- License selection (must match repo `LICENSE`)

## 4) Common rejection reasons (quick scan)

- Declared Godot version doesn’t match reality (asset fails to run).
- License mismatch, missing license file, or missing copyright statement in the license file.
- Icon URL isn’t a direct link to an image (GitHub page URL instead of raw).
- Repo requires submodule content to function.
- Too much generated/editor cache content committed (bad `.gitignore`).
- Warnings/errors in the editor output on first run/enable.

