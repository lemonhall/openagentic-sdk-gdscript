# VR Offices: Install Skills from GitHub Subdirectory URLs (PRD)

## Vision

Users can install skills from GitHub links that point to a **repo subdirectory** (e.g. `.../tree/main/skills/writer-memory`), not only from repo root URLs.

Key constraint: downloading still happens via GitHub ZIP; after unzip, the installer must scope discovery to the requested subdirectory to avoid installing unrelated skills from the same repo.

## Requirements

### REQ-001 — Parse GitHub subdirectory URLs

Support GitHub URLs in these forms as install sources:

- Repo root:
  - `https://github.com/<owner>/<repo>`
- Tree URL (branch + optional subdir):
  - `https://github.com/<owner>/<repo>/tree/<ref>`
  - `https://github.com/<owner>/<repo>/tree/<ref>/<subdir>`
- Blob URL (file link; treat as directory containing file):
  - `https://github.com/<owner>/<repo>/blob/<ref>/<path>` (if `<path>` ends with `SKILL.md`, use its parent directory as `<subdir>`)

For tree/blob URLs, `<ref>` can be `main` or `master` (MVP; other refs are treated as literal `<ref>` string).

### REQ-002 — Download ZIP for the specified ref when provided

- If the install URL includes `/tree/<ref>` or `/blob/<ref>`, download the ZIP for that `<ref>` (do not auto-fallback to other refs).
- If the install URL is repo root without a ref, keep existing behavior (try `main`, then `master`).

### REQ-003 — Install only from requested subdir when provided

If the URL includes a `<subdir>`:

- After unzip, discovery/validation/install should scan **only within that subdir** (not the entire repo).
- If the subdir does not exist in the zip, surface a readable error (no crash).

### REQ-004 — Master branch tree URLs work

Example URL must be supported:

- `https://github.com/TencentBlueKing/bk-ci/tree/master/ai/skills/skill-writer`

## Non-Goals

- Resolving complex refs with slashes via GitHub APIs.
- Supporting non-GitHub hosts.
- Teaching the installed skill to an NPC (deferred).

## Acceptance

- New automated test installs from a `/tree/<ref>/<subdir>` URL and confirms only skills under that subdir are installed.
- Existing suites still pass:
  - `scripts/run_godot_tests.sh --suite openagentic`
  - `scripts/run_godot_tests.sh --suite vr_offices`

