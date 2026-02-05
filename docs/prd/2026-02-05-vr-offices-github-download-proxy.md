# VR Offices: GitHub Skill ZIP Download Proxy (PRD)

## Vision

When installing skills from GitHub inside `VendingMachineOverlay`, downloads should be able to use a user-configured HTTP(S) proxy to avoid network failures in environments where direct GitHub access is blocked.

Critical constraint: **only** the GitHub ZIP download path uses this proxy. SkillsMP search and other HTTP calls must be unaffected.

## Requirements

### REQ-001 — Proxy fields in VendingMachineOverlay settings

In `vr_offices/ui/VendingMachineOverlay.tscn` settings popup, add:

- `HTTP proxy` input (default: `http://127.0.0.1:7897`)
- `HTTPS proxy` input (default: `https://127.0.0.1:7897`)

### REQ-002 — Persist proxy per save slot

Proxy fields are saved alongside the existing SkillsMP API key config, per save slot (`save_id`):

- Same storage as current SkillsMP config:
  - `user://openagentic/saves/<save_id>/shared/skillsmp_config.json`
- New keys (MVP):
  - `proxy_http`
  - `proxy_https`

### REQ-003 — Apply proxy ONLY to GitHub ZIP downloads

Only the GitHub skill ZIP download code path uses the proxy:

- Affects `VrOfficesGitHubZipSource.download_repo_zip()`.
- Must not change behavior of:
  - SkillsMP search (`/api/v1/skills/search`)
  - Tavily/Media/OpenAI proxy plumbing
  - Any other HTTP in the project

### REQ-004 — Error handling

- If proxy is malformed/unusable, show a readable error on install (do not crash).
- If no proxy is set, behavior is unchanged from today (direct download).

## Non-Goals

- Auto-detect system proxies.
- SOCKS proxies (HTTP(S) only).
- Global proxy settings.

## Acceptance

- Automated test confirms `skillsmp_config.json` persists and reloads `proxy_http` / `proxy_https`.
- VendingMachineOverlay loads/saves proxy fields in settings.
- Existing suites still pass:
  - `scripts/run_godot_tests.sh --suite openagentic`
  - `scripts/run_godot_tests.sh --suite vr_offices`

