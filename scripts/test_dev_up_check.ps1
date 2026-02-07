Param()

$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")

# Minimal env required for `--check` mode.
$env:OPENAI_API_KEY = "sk-test"
$env:OPENAGENTIC_MEDIA_BEARER_TOKEN = "dev-token"

$pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
$psCmd = Get-Command powershell -ErrorAction SilentlyContinue

$shell = if ($pwshCmd) { $pwshCmd.Source } elseif ($psCmd) { $psCmd.Source } else { "" }
if ([string]::IsNullOrWhiteSpace($shell)) {
  Write-Host "Missing PowerShell executable (pwsh/powershell) in PATH."
  exit 1
}

$launcher = Join-Path $RootDir "dev-up.ps1"

$p = Start-Process -FilePath $shell -ArgumentList @(
  "-NoProfile",
  "-File",
  $launcher,
  "--check",
  "--no-daemon"
) -NoNewWindow -Wait -PassThru

if ($p.ExitCode -ne 0) {
  Write-Host ("dev-up.ps1 --check failed (exit {0})" -f $p.ExitCode)
  exit $p.ExitCode
}

Write-Host "OK"

