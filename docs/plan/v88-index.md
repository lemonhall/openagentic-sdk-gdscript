# v88 index

Goal: provide a Windows PowerShell launcher equivalent to `dev-up.sh`.

## Artifacts

- Plan: `docs/plan/v88-windows-dev-up-powershell.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | Add a PowerShell `--check` verification script | `pwsh -NoProfile -File scripts/test_dev_up_check.ps1` | done |
| M2 | Implement `dev-up.ps1` (proxy/media/daemon + `--check`) | `pwsh -NoProfile -File scripts/test_dev_up_check.ps1` | done |
| M3 | Document PowerShell workflow in README | N/A | done |

## Evidence

- 2026-02-07:
  - `pwsh -NoProfile -File scripts/test_dev_up_check.ps1` → OK

