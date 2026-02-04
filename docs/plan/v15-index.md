# v15 Index — Root Dev Launcher + Unified .env

## Vision (v15)

Local development should be one command instead of three terminals:

- Start **proxy + media service + rust remote daemon** together from repo root.
- All keys/config are standardized in a single root `.env` (with a committed `.env.example`).

## Milestones (facts panel)

1. **Plan:** write an executable v15 plan with a check command. (done)
2. **Env:** add root `.env.example` and ensure secrets are ignored. (done)
3. **Launcher:** add `dev-up.sh` to start the three processes. (done)
4. **Verify:** add a lightweight check script and run it. (done)

## Plans (v15)

- `docs/plan/v15-root-dev-launcher-and-env.md`

## Definition of Done (DoD)

- Root `.env` is ignored by git; `.env.example` is committed.
- `dev-up.sh --check` validates required tooling/env and exits non-zero on missing requirements.
- `dev-up.sh` starts:
  - `proxy/server.mjs` on `OPENAGENTIC_PROXY_HOST:OPENAGENTIC_PROXY_PORT`
  - `media_service/server.mjs` on `OPENAGENTIC_MEDIA_HOST:OPENAGENTIC_MEDIA_PORT`
  - `remote_daemon` via `cargo run` (unless `--no-daemon`)
- A minimal regression check exists (`scripts/test_dev_up_check.sh`) and passes.

## Verification

- `bash scripts/test_dev_up_check.sh`
- Optional:
  - `bash dev-up.sh --check --no-daemon`

