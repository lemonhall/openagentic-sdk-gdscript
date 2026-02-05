# VR Offices: Shared Skill Library (“Library”) PRD

## Vision

Build a “shared library” of Skills for a save slot: the user can download a GitHub repo ZIP, unpack it, validate discovered `SKILL.md` skill directories, and manage the installed skills inside `VendingMachineOverlay` (Library tab). This is a “library construction” milestone; “teaching” an NPC is a later milestone.

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

### REQ-006 — UI: add a “Library” tab to VendingMachineOverlay

In `vr_offices/ui/VendingMachineOverlay.tscn`:

- Keep existing Search tab unchanged.
- Add a `Library` tab that supports (MVP):
  - list installed skills (name + description)
  - add/install skill pack from a GitHub repo URL input + Install button
  - delete/uninstall selected skill
  - view validation/installation status text

### REQ-007 — (Deferred) Assign a shared skill to an NPC

Place the UI affordance on the Library tab (selection + “Assign” button), but **do not implement the copy into the NPC private workspace in the library milestone**.

Rationale: teaching/ownership and per-NPC skill lifecycle needs its own acceptance + persistence story.

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

