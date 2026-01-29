Param(
  [string]$GodotExe = $env:GODOT_WIN_EXE,
  [string]$One = "",
  [int]$TimeoutSec = $(if ($env:GODOT_TEST_TIMEOUT_SEC) { [int]$env:GODOT_TEST_TIMEOUT_SEC } else { 120 }),
  [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = "Stop"

function Usage {
  Write-Host @"
Run Godot headless test scripts from Windows (PowerShell).

Usage:
  scripts/run_godot_tests.ps1 [-GodotExe <path-to-godot-console-exe>] [-One <test_script.gd>] [-TimeoutSec <seconds>] [-ExtraArgs <args...>]

Examples:
  scripts/run_godot_tests.ps1
  scripts/run_godot_tests.ps1 -GodotExe "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"
  scripts/run_godot_tests.ps1 -One tests\test_sse_parser.gd
  scripts/run_godot_tests.ps1 -TimeoutSec 120
  scripts/run_godot_tests.ps1 -One tests\test_vr_offices_smoke.gd -ExtraArgs --verbose

Notes:
  - Use the *console* exe for reliable headless output.
  - You can also set GODOT_WIN_EXE to avoid passing -GodotExe every time.
  - To avoid hung tests, set GODOT_TEST_TIMEOUT_SEC or pass -TimeoutSec.
"@
}

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
  $DefaultDir = "E:\Godot_v4.6-stable_win64.exe"
  $DefaultExe = Join-Path $DefaultDir "Godot_v4.6-stable_win64_console.exe"
  if (Test-Path $DefaultExe) {
    $GodotExe = $DefaultExe
  }
}

if ([string]::IsNullOrWhiteSpace($GodotExe) -or !(Test-Path $GodotExe)) {
  Write-Host "Godot exe not found. Set GODOT_WIN_EXE or pass -GodotExe."
  Usage
  exit 2
}

$tests = @()
if (![string]::IsNullOrWhiteSpace($One)) {
  $tests = @($One)
} else {
  $tests = Get-ChildItem -Path (Join-Path $RootDir "tests") -Filter "test_*.gd" -File |
    Sort-Object FullName |
    ForEach-Object { $_.FullName }

  if ($tests.Count -eq 0) {
    Write-Host "No tests found under tests\test_*.gd"
    exit 2
  }
}

$status = 0
foreach ($t in $tests) {
  $scriptPath = $t
  if (!(Test-Path $scriptPath)) {
    $scriptPath = Join-Path $RootDir $t
  }
  if (!(Test-Path $scriptPath)) {
    Write-Host "Missing test script: $t"
    $status = 1
    continue
  }

  Write-Host "--- RUN $t"
  $out = Join-Path $env:TEMP ("godot-test-out-" + [Guid]::NewGuid().ToString("N") + ".txt")
  $err = Join-Path $env:TEMP ("godot-test-err-" + [Guid]::NewGuid().ToString("N") + ".txt")

  $args = @()
  if ($ExtraArgs.Count -gt 0) { $args += $ExtraArgs }
  $args += @("--headless", "--path", $RootDir, "--script", $scriptPath)

  $p = Start-Process -FilePath $GodotExe -ArgumentList $args -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
  $exited = $p.WaitForExit($TimeoutSec * 1000)
  if (-not $exited) {
    try { $p.Kill($true) } catch { try { Stop-Process -Id $p.Id -Force } catch {} }
    Write-Host ("TIMEOUT after {0}s: {1}" -f $TimeoutSec, $t)
    $status = 1
  }

  if (Test-Path $out) { Get-Content $out | Write-Host }
  if (Test-Path $err) { Get-Content $err | Write-Host }
  Remove-Item -ErrorAction SilentlyContinue $out, $err

  if ($p.ExitCode -ne 0) { $status = 1 }
}

exit $status
