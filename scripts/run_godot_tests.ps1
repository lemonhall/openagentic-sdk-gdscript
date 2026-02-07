Param(
  [string]$GodotExe = $env:GODOT_WIN_EXE,
  [string]$Suite = "all",
  [string]$One = "",
  [int]$TimeoutSec = $(if ($env:GODOT_TEST_TIMEOUT_SEC) { [int]$env:GODOT_TEST_TIMEOUT_SEC } else { 120 }),
  [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = "Stop"

function Quote-Arg([string]$a) {
  if ($null -eq $a) { return '""' }
  if ($a -match '[\s"]') {
    $escaped = $a -replace '"', '\\"'
    return '"' + $escaped + '"'
  }
  return $a
}

function Run-ProcessCapture {
  Param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Args,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][int]$TimeoutMs
  )

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FilePath
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.Arguments = (($Args | ForEach-Object { Quote-Arg $_ }) -join ' ')

  $p = [System.Diagnostics.Process]::new()
  $p.StartInfo = $psi
  [void]$p.Start()

  $exited = $p.WaitForExit($TimeoutMs)
  if (-not $exited) {
    try { $p.Kill($true) } catch { try { Stop-Process -Id $p.Id -Force } catch {} }
    return @{
      ok = $false
      timed_out = $true
      exit_code = 1
      stdout = ""
      stderr = ""
    }
  }

  # Drain pipes *after* exit, then wait again to ensure streams flush.
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  return @{
    ok = $true
    timed_out = $false
    exit_code = [int]$p.ExitCode
    stdout = $stdout
    stderr = $stderr
  }
}

function Usage {
  Write-Host @"
Run Godot headless test scripts from Windows (PowerShell).

Usage:
  scripts/run_godot_tests.ps1 [-GodotExe <path-to-godot-console-exe>] [-Suite <name>] [-One <test_script.gd>] [-TimeoutSec <seconds>] [-ExtraArgs <args...>]

Examples:
  scripts/run_godot_tests.ps1
  scripts/run_godot_tests.ps1 -GodotExe "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"
  scripts/run_godot_tests.ps1 -Suite openagentic
  scripts/run_godot_tests.ps1 -Suite vr_offices
  scripts/run_godot_tests.ps1 -One tests\addons\openagentic\test_sse_parser.gd
  scripts/run_godot_tests.ps1 -TimeoutSec 120
  scripts/run_godot_tests.ps1 -One tests\test_vr_offices_smoke.gd -ExtraArgs --verbose

Suites:
  all (default), openagentic, irc_client, vr_offices, demo, demo_irc, demo_rpg, addons, projects

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
  $suiteDir = Join-Path $RootDir "tests"
  switch ($Suite) {
    "all" { $suiteDir = Join-Path $RootDir "tests" }
    "addons" { $suiteDir = Join-Path $RootDir "tests\\addons" }
    "projects" { $suiteDir = Join-Path $RootDir "tests\\projects" }
    "openagentic" { $suiteDir = Join-Path $RootDir "tests\\addons\\openagentic" }
    "irc_client" { $suiteDir = Join-Path $RootDir "tests\\addons\\irc_client" }
    "vr_offices" { $suiteDir = Join-Path $RootDir "tests\\projects\\vr_offices" }
    "demo" { $suiteDir = Join-Path $RootDir "tests\\projects\\demo" }
    "demo_irc" { $suiteDir = Join-Path $RootDir "tests\\projects\\demo_irc" }
    "demo_rpg" { $suiteDir = Join-Path $RootDir "tests\\projects\\demo_rpg" }
    default {
      Write-Host ("Unknown suite: {0}" -f $Suite)
      Usage
      exit 2
    }
  }

  $tests = Get-ChildItem -Path $suiteDir -Recurse -Filter "test_*.gd" -File |
    Sort-Object FullName |
    ForEach-Object { $_.FullName }

  if ($tests.Count -eq 0) {
    Write-Host ("No tests found under {0}\\**\\test_*.gd" -f $suiteDir)
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
  $args = @()
  if ($ExtraArgs.Count -gt 0) { $args += $ExtraArgs }
  $args += @("--headless", "--path", $RootDir.Path, "--script", $scriptPath)

  $res = Run-ProcessCapture -FilePath $GodotExe -Args $args -WorkingDirectory $RootDir.Path -TimeoutMs ($TimeoutSec * 1000)
  if ($res.stdout) { $res.stdout | Write-Host }
  if ($res.stderr) { $res.stderr | Write-Host }

  if ($res.timed_out) {
    Write-Host ("TIMEOUT after {0}s: {1}" -f $TimeoutSec, $t)
    $status = 1
    continue
  }
  if ($res.exit_code -ne 0) { $status = 1 }
}

exit $status
