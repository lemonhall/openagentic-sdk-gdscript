Param(
  [string]$GodotExe = $env:GODOT_WIN_EXE,
  [string]$One = ""
)

$ErrorActionPreference = "Stop"

function Usage {
  Write-Host @"
Run Godot headless test scripts from Windows (PowerShell).

Usage:
  scripts/run_godot_tests.ps1 [-GodotExe <path-to-godot-console-exe>] [-One <test_script.gd>]

Examples:
  scripts/run_godot_tests.ps1
  scripts/run_godot_tests.ps1 -GodotExe "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"
  scripts/run_godot_tests.ps1 -One tests\test_sse_parser.gd

Notes:
  - Use the *console* exe for reliable headless output.
  - You can also set GODOT_WIN_EXE to avoid passing -GodotExe every time.
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
  & $GodotExe --headless --path $RootDir --script $scriptPath
  if ($LASTEXITCODE -ne 0) {
    $status = 1
  }
}

exit $status

