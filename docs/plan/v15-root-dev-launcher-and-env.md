# v15 Plan — Root Dev Launcher + Unified .env

## Goal

Reduce local dev friction by providing:

- A single root `.env` for Node/Python/Rust/Godot config
- A root script that starts proxy + media service + rust remote daemon in one command

## PRD Trace

- DevEx: eliminate multi-terminal startup overhead for proxy/media/daemon and standardize keys.

## Scope

**In scope**
- Add `.env.example` and ignore `.env`.
- Add `dev-up.sh` with:
  - `.env` loading
  - `--check`
  - `--no-proxy/--no-media/--no-daemon`
  - log files under `.dev/`
- Add a small check script for quick verification.
- Update README docs to reference the new workflow.

**Out of scope**
- Installing dependencies (`npm install`, etc.)
- Starting an IRC server (the remote daemon only connects to one)
- Making the Godot editor automatically inherit env vars (depends on how Godot is launched)

## Acceptance

- Running `bash scripts/test_dev_up_check.sh` succeeds on a machine with `bash` + `node` installed.
- `dev-up.sh` does not require `HOST`/`PORT` env vars (no cross-service collision); it uses namespaced variables.

## Files

- Add:
  - `.env.example`
  - `dev-up.sh`
  - `scripts/test_dev_up_check.sh`
- Update:
  - `.gitignore`
  - `README.md`
  - `README.zh-CN.md`

## Steps (Red → Green → Refactor)

1) **Red**: add `scripts/test_dev_up_check.sh` that calls `dev-up.sh --check --no-daemon` (fails before launcher exists).
2) **Green**: implement `dev-up.sh` with `--check` to make the test pass.
3) **Refactor**: keep the launcher minimal; avoid adding extra features not required by Acceptance.

## Risks

- `.env` is bash-sourced; invalid syntax will break startup. Mitigate by keeping `.env.example` shell-compatible.
- Credentials must never be committed. Mitigate via `.gitignore` and docs.

