# VR Offices: Shared Skill Library (“Library”) PRD

## Vision

Build a “shared library” of Skills for a save slot: the user can download a GitHub repo ZIP, unpack it, validate discovered `SKILL.md` skill directories, and manage the installed skills inside `VendingMachineOverlay` (Library tab). This is a “library construction” milestone; “teaching” an NPC is a later milestone.

## Tab Responsibilities (must be explicit)

- **Tab 1: Search** = “找 / 装 / 验”
  - Find remote skills (market/search).
  - Show details (including GitHub repo URL when available).
  - Install from the selected skill’s repo URL.
  - Show validation/install result.
- **Tab 2: Library** = “管”
  - Manage the local shared library (search/filter, list, uninstall, view details).
  - (Optional UI placeholder only) show an affordance to assign/teach an NPC, but do not implement teaching in this milestone.

## Terminology

- **Skill directory**: a folder that contains `SKILL.md` at its root.
- **Shared library**: per-save public storage under `user://openagentic/saves/<save_id>/shared/skill_library/`.
- **Installed skill**: a validated skill directory copied into the shared library and shown as “available”.

## Requirements

### REQ-001 — GitHub repo ZIP download (main → master fallback)

Given a GitHub repo URL like `https://github.com/<owner>/<repo>` (optional `.git` suffix), download a ZIP of the repository:

- Try default ref `main`, if 404/failed then try `master`.
- ZIP URL uses `codeload.github.com` to avoid redirect issues:
  - `https://codeload.github.com/<owner>/<repo>/zip/refs/heads/<ref>`
- Must support a per-request timeout and show a readable failure message.

### REQ-002 — Unzip into a safe staging directory

After download:

- Save ZIP to a per-save staging directory under `user://` (or a temp folder under the save root).
- Unpack using Godot ZIPReader into staging.
- Enforce safety constraints:
  - reject path traversal entries (`..`, absolute paths)
  - enforce max uncompressed size and max file count (configurable constants)
  - enforce a max ZIP byte size (configurable)

### REQ-003 — Discover skill directories inside the unpacked tree

Discovery rules (MVP):

- Scan the unpack root and its subdirectories up to a small depth (e.g. 4).
- Any directory containing `SKILL.md` is treated as a candidate skill.
- A repo may contain multiple skills; install each valid skill independently.

### REQ-004 — Validate `SKILL.md` (basic spec + encoding)

Validation rules (MVP):

1) `SKILL.md` must be readable as UTF-8 (no replacement characters / decoding failure).
2) Must begin with YAML frontmatter:
   - first non-empty line is `---`
   - a later line is `---` closing the header
3) YAML header must include at least:
   - `name` (string, non-empty)
   - `description` (string, non-empty)
4) `name` must be safe for directory naming:
   - recommended pattern: `^[a-z0-9][a-z0-9._-]{0,63}$`
5) File size guardrails:
   - `SKILL.md` must be <= 256 KiB (configurable).

If validation fails, the skill is not installed; the user sees the specific reason.

### REQ-005 — Install into shared library and mark “available”

For each validated skill directory:

- Copy the entire directory into:
  - `user://openagentic/saves/<save_id>/shared/skill_library/<skill_name>/`
- Write/update a shared library manifest:
  - `user://openagentic/saves/<save_id>/shared/skill_library/index.json`
  - Fields (MVP): `name`, `description`, `source`, `installed_at_unix`, `path`
- If the skill already exists:
  - MVP behavior: reject and require uninstall first (no in-place update).

### REQ-006 — UI: Search tab supports “install from selected skill”

In `vr_offices/ui/VendingMachineOverlay.tscn`:

- The Search tab shows the selected skill’s GitHub repo URL (when available in the remote result payload).
- The Search tab includes an `Install` button in the selected skill detail area:
  - Install uses the selected skill’s repo URL (no separate “library tab install input”).
  - While installing/validating, UI shows a loading state and a status message.
- The Search tab detail area also shows the repo URL as a clickable link when feasible:
  - Prefer `OS.shell_open(url)` for opening in the system browser.
  - In headless/server builds, clicking should be a no-op and must not error/crash.

### REQ-007 — UI: add a “Library” tab for local management (“管”)

In `vr_offices/ui/VendingMachineOverlay.tscn`:

- Add a `Library` tab that supports (MVP):
  - local search/filter input (for many installed skills)
  - list installed skills (name + description)
  - view selected skill details (including installed source URL)
  - delete/uninstall selected skill
  - status text for operations

### REQ-008 — Library: local search/filter behavior

- The Library tab provides a query input that filters installed skills by:
  - skill name
  - description
- Filtering is in-memory (manifest-backed), no indexing required.

### REQ-009 — (Deferred) Assign/teach a shared skill to an NPC

Place the UI affordance on the Library tab (selection + “Assign” button), but **do not implement the copy into the NPC private workspace in the library milestone**.

Rationale: teaching/ownership and per-NPC skill lifecycle needs its own acceptance + persistence story.

### REQ-010 — Uninstall truly removes the skill directory (reinstall works)

- Uninstall must remove:
  - the skill directory under `shared/skill_library/<skill_name>/` (including the root folder itself), and
  - the manifest entry.
- After uninstall, installing the same skill again must succeed (no false “AlreadyInstalled” due to empty leftover dirs).

### REQ-011 — Library: open the shared library folder in OS file manager

- The Library tab includes an `Open Folder` button that opens:
  - `user://openagentic/saves/<save_id>/shared/skill_library/`
  - using `OS.shell_open(ProjectSettings.globalize_path(path))`.
- In headless/server builds, it must be a no-op and must not error/crash.

## Non-Goals (MVP)

- Git clone, branches/tags selection, private repo auth flows.
- Semantic search / AI search for remote marketplace.
- Updates, lockfiles, version pinning, diffing installed skills.
- Executing any scripts from downloaded skills.
- Modifying `demo_rpg/`.

## Persistence & Paths

- Shared library root (per save): `user://openagentic/saves/<save_id>/shared/skill_library/`
  - Skill: `<skill_name>/SKILL.md` (+ any files)
  - Manifest: `index.json`
- Staging root (per save): `user://openagentic/saves/<save_id>/shared/skill_library_staging/` (or similar)

## Testing & Verification (must be automated)

- ZIP install flow works with a locally generated ZIP in tests (no real network):
  - install succeeds and files are copied to expected `user://` location
- Validator rejects:
  - missing `SKILL.md`
  - missing YAML header
  - missing required keys
  - invalid `name`
  - non-UTF8 / decode failure cases (as feasible)
- UI renders installed list and updates status text after install/uninstall calls.
