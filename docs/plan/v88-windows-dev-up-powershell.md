# v88 Plan — Windows PowerShell `dev-up.ps1`

## Goal

Provide a Windows-friendly launcher equivalent to `dev-up.sh` so developers can start:

1) Node proxy (`proxy/server.mjs`)
2) Media service (`media_service/server.mjs`)
3) Rust remote daemon (`remote_daemon`)

…from PowerShell with a shared `.env`.

## Scope

**In scope**
- Add `dev-up.ps1` at repo root with:
  - `.env` loading (simple `KEY=VALUE` parsing; quotes supported)
  - `--check`
  - `--no-proxy/--no-media/--no-daemon`
  - logs under `.dev/logs/`
  - optional `<command...>` execution under the same env
- Add `scripts/test_dev_up_check.ps1` for quick verification.
- Update `README.md` + `README.zh-CN.md` with PowerShell usage.

**Out of scope**
- Installing dependencies (`npm install`, etc.)
- Making `cmd.exe` / `.bat` wrappers.
- Full bash-compatible `.env` evaluation (e.g. variable interpolation).

## Acceptance

- `pwsh -NoProfile -File scripts/test_dev_up_check.ps1` succeeds on a machine with `pwsh` and `node`.
- `dev-up.ps1 --check` exits non-zero when required commands/env vars are missing.
- Service logs are written to `.dev/logs/*.log` and `.dev/logs/*.err.log`.

## Files

- Add:
  - `dev-up.ps1`
  - `scripts/test_dev_up_check.ps1`
- Update:
  - `README.md`
  - `README.zh-CN.md`

## Steps (Red → Green → Refactor)

1) **Red**: add `scripts/test_dev_up_check.ps1` that expects `dev-up.ps1 --check` to pass (fails when launcher missing).
2) **Green**: implement `dev-up.ps1` with `--check` so the verification script passes.
3) **Refactor**: keep parity with `dev-up.sh`; keep logs and docs clear.
