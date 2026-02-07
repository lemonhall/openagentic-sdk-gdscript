Param()

$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path $PSScriptRoot
Set-Location $RootDir

function Usage {
  Write-Host @"
Usage:
  pwsh -NoProfile -File dev-up.ps1 [options] [<command...>]

Starts 3 local dev processes:
  1) Node proxy         (proxy/server.mjs)
  2) Media service      (media_service/server.mjs)
  3) Rust remote daemon (remote_daemon; connects to IRC)

Options:
  --check         Validate env + tools, then exit (no processes started)
  --no-proxy      Do not start proxy
  --no-media      Do not start media service
  --no-daemon     Do not start rust remote daemon
  -h, --help      Show help

Environment:
  Loads `.env` from repo root if present (KEY=VALUE format).
  See `.env.example` for supported variables.

Examples:
  Copy-Item .env.example .env
  pwsh -NoProfile -File dev-up.ps1
  pwsh -NoProfile -File dev-up.ps1 --no-daemon
  pwsh -NoProfile -File dev-up.ps1 --no-daemon godot4 --path .
"@
}

function Import-DotEnv([string]$path) {
  if (!(Test-Path $path)) { return }

  foreach ($rawLine in (Get-Content -Path $path)) {
    $line = $rawLine.Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line.StartsWith("#")) { continue }

    if ($line.StartsWith("export ")) {
      $line = $line.Substring(7).Trim()
    }

    $eq = $line.IndexOf("=")
    if ($eq -lt 1) { continue }

    $key = $line.Substring(0, $eq).Trim()
    if ([string]::IsNullOrWhiteSpace($key)) { continue }

    $valuePart = $line.Substring($eq + 1).Trim()
    $value = ""

    if ($valuePart.Length -eq 0) {
      $value = ""
    } elseif ($valuePart.StartsWith('"') -or $valuePart.StartsWith("'")) {
      $quote = $valuePart.Substring(0, 1)
      $rest = $valuePart.Substring(1)
      $end = $rest.IndexOf($quote)
      if ($end -ge 0) {
        $value = $rest.Substring(0, $end)
      } else {
        $value = $rest
      }
    } else {
      $hash = $valuePart.IndexOf("#")
      if ($hash -ge 0) {
        $value = $valuePart.Substring(0, $hash).Trim()
      } else {
        $value = $valuePart
      }
    }

    Set-Item -Path ("Env:{0}" -f $key) -Value $value
  }
}

$check = $false
$noProxy = $false
$noMedia = $false
$noDaemon = $false
$cmdTokens = @()

:argloop for ($i = 0; $i -lt $args.Count; $i++) {
  $a = [string]$args[$i]
  switch ($a) {
    "--check" { $check = $true; continue }
    "--no-proxy" { $noProxy = $true; continue }
    "--no-media" { $noMedia = $true; continue }
    "--no-daemon" { $noDaemon = $true; continue }
    "-h" { Usage; exit 0 }
    "--help" { Usage; exit 0 }
    "--" {
      if ($i + 1 -le $args.Count - 1) {
        $cmdTokens = @($args[($i + 1)..($args.Count - 1)])
      } else {
        $cmdTokens = @()
      }
      break argloop
    }
    default {
      if ($a.StartsWith("-")) {
        Write-Host ("Unknown arg: {0}" -f $a)
        Write-Host ""
        Usage
        exit 2
      }
      $cmdTokens = @($args[$i..($args.Count - 1)])
      break argloop
    }
  }
}

Import-DotEnv (Join-Path $RootDir ".env")

$ircHostEnv = if ($env:OA_IRC_HOST) { $env:OA_IRC_HOST } else { "" }
$ircPortEnv = if ($env:OA_IRC_PORT) { $env:OA_IRC_PORT } else { "" }

# Keep a single source of truth across components:
# - Rust remote daemon reads OA_IRC_*
# - VR Offices reads VR_OFFICES_IRC_*
# If either side is set, mirror it to the other when missing.
if ([string]::IsNullOrWhiteSpace($env:VR_OFFICES_IRC_HOST) -and -not [string]::IsNullOrWhiteSpace($env:OA_IRC_HOST)) {
  $env:VR_OFFICES_IRC_HOST = $env:OA_IRC_HOST
}
if ([string]::IsNullOrWhiteSpace($env:VR_OFFICES_IRC_PORT) -and -not [string]::IsNullOrWhiteSpace($env:OA_IRC_PORT)) {
  $env:VR_OFFICES_IRC_PORT = $env:OA_IRC_PORT
}
if ([string]::IsNullOrWhiteSpace($env:VR_OFFICES_IRC_PASSWORD) -and -not [string]::IsNullOrWhiteSpace($env:OA_IRC_PASSWORD)) {
  $env:VR_OFFICES_IRC_PASSWORD = $env:OA_IRC_PASSWORD
}

if ([string]::IsNullOrWhiteSpace($env:OA_IRC_HOST) -and -not [string]::IsNullOrWhiteSpace($env:VR_OFFICES_IRC_HOST)) {
  $env:OA_IRC_HOST = $env:VR_OFFICES_IRC_HOST
}
if ([string]::IsNullOrWhiteSpace($env:OA_IRC_PORT) -and -not [string]::IsNullOrWhiteSpace($env:VR_OFFICES_IRC_PORT)) {
  $env:OA_IRC_PORT = $env:VR_OFFICES_IRC_PORT
}
if ([string]::IsNullOrWhiteSpace($env:OA_IRC_PASSWORD) -and -not [string]::IsNullOrWhiteSpace($env:VR_OFFICES_IRC_PASSWORD)) {
  $env:OA_IRC_PASSWORD = $env:VR_OFFICES_IRC_PASSWORD
}

$proxyHost = if ($env:OPENAGENTIC_PROXY_HOST) { $env:OPENAGENTIC_PROXY_HOST } else { "127.0.0.1" }
$proxyPort = if ($env:OPENAGENTIC_PROXY_PORT) { $env:OPENAGENTIC_PROXY_PORT } else { "8787" }
$mediaHost = if ($env:OPENAGENTIC_MEDIA_HOST) { $env:OPENAGENTIC_MEDIA_HOST } else { "127.0.0.1" }
$mediaPort = if ($env:OPENAGENTIC_MEDIA_PORT) { $env:OPENAGENTIC_MEDIA_PORT } else { "8788" }

if (-not $env:OPENAGENTIC_PROXY_BASE_URL) {
  $env:OPENAGENTIC_PROXY_BASE_URL = ("http://{0}:{1}/v1" -f $proxyHost, $proxyPort)
}
if (-not $env:OPENAGENTIC_MEDIA_BASE_URL) {
  $env:OPENAGENTIC_MEDIA_BASE_URL = ("http://{0}:{1}" -f $mediaHost, $mediaPort)
}
if (-not $env:OPENAGENTIC_GEMINI_BASE_URL) {
  $env:OPENAGENTIC_GEMINI_BASE_URL = ("http://{0}:{1}/gemini" -f $proxyHost, $proxyPort)
}

$missing = 0
function Need-Command([string]$name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    Write-Host ("Missing required command: {0}" -f $name)
    $script:missing = 1
  }
}

if (-not $noProxy) {
  Need-Command "node"
  if ([string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
    Write-Host "Missing required env: OPENAI_API_KEY (needed by proxy)"
    $missing = 1
  }
}

if (-not $noMedia) {
  Need-Command "node"
  if ([string]::IsNullOrWhiteSpace($env:OPENAGENTIC_MEDIA_BEARER_TOKEN)) {
    Write-Host "Missing required env: OPENAGENTIC_MEDIA_BEARER_TOKEN (needed by media service)"
    $missing = 1
  }
}

if (-not $noDaemon) {
  Need-Command "cargo"
}

if ($check) {
  if ($missing -ne 0) {
    Write-Host ""
    Write-Host "Hint: copy `.env.example` to `.env` and fill required values."
  }
  exit $missing
}

$devDir = Join-Path $RootDir ".dev"
$logDir = Join-Path $devDir "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$services = @()

function Start-LoggedProcess {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$ArgumentList,
    [Parameter(Mandatory = $true)][string]$StdoutLog,
    [Parameter(Mandatory = $true)][string]$StderrLog
  )

  $p = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $RootDir -NoNewWindow -PassThru `
    -RedirectStandardOutput $StdoutLog -RedirectStandardError $StderrLog

  $script:services += [pscustomobject]@{
    Name = $Name
    Process = $p
    StdoutLog = $StdoutLog
    StderrLog = $StderrLog
  }

  Write-Host ("[dev-up] {0} pid: {1} (log: {2}; err: {3})" -f $Name, $p.Id, $StdoutLog, $StderrLog)
}

function Stop-ServiceProcess([object]$svc) {
  $p = $svc.Process
  if (-not $p) { return }
  if ($p.HasExited) { return }

  try {
    try { $p.Kill($true) } catch { Stop-Process -Id $p.Id -Force }
  } catch {}
}

try {
  Write-Host ("[dev-up] proxy: {0}" -f $env:OPENAGENTIC_PROXY_BASE_URL)
  Write-Host ("[dev-up] gemini: {0}" -f $env:OPENAGENTIC_GEMINI_BASE_URL)
  Write-Host ("[dev-up] media: {0}" -f $env:OPENAGENTIC_MEDIA_BASE_URL)

  if (-not $noProxy) {
    Write-Host "[dev-up] starting proxy..."
    Start-LoggedProcess -Name "proxy" -FilePath "node" -ArgumentList @(
      (Join-Path $RootDir "proxy\\server.mjs"),
      "--host", $proxyHost,
      "--port", $proxyPort
    ) -StdoutLog (Join-Path $logDir "proxy.log") -StderrLog (Join-Path $logDir "proxy.err.log")
  }

  if (-not $noMedia) {
    Write-Host "[dev-up] starting media service..."
    $storeDir = if ($env:OPENAGENTIC_MEDIA_STORE_DIR) {
      $env:OPENAGENTIC_MEDIA_STORE_DIR
    } else {
      Join-Path ([System.IO.Path]::GetTempPath()) "oa-media"
    }
    try { New-Item -ItemType Directory -Force -Path $storeDir | Out-Null } catch {}

    Start-LoggedProcess -Name "media" -FilePath "node" -ArgumentList @(
      (Join-Path $RootDir "media_service\\server.mjs"),
      "--host", $mediaHost,
      "--port", $mediaPort,
      "--store-dir", $storeDir
    ) -StdoutLog (Join-Path $logDir "media.log") -StderrLog (Join-Path $logDir "media.err.log")
  }

  if (-not $noDaemon) {
    Write-Host "[dev-up] starting rust remote daemon..."
    $oaHost = if ($env:OA_IRC_HOST) { $env:OA_IRC_HOST } else { "127.0.0.1" }
    $oaPort = if ($env:OA_IRC_PORT) { $env:OA_IRC_PORT } else { "6667" }
    Write-Host ("[dev-up] remote daemon target: {0}:{1}" -f $oaHost, $oaPort)

    $daemonArgs = @("--host", $oaHost, "--port", $oaPort)
    if ($env:OA_IRC_PASSWORD) { $daemonArgs += @("--password", $env:OA_IRC_PASSWORD) }
    if ($env:OA_IRC_NICK) { $daemonArgs += @("--nick", $env:OA_IRC_NICK) }
    if ($env:OA_IRC_USER) { $daemonArgs += @("--user", $env:OA_IRC_USER) }
    if ($env:OA_IRC_REALNAME) { $daemonArgs += @("--realname", $env:OA_IRC_REALNAME) }

    if ($env:OA_REMOTE_POLL_SECONDS) { $daemonArgs += @("--poll-seconds", $env:OA_REMOTE_POLL_SECONDS) }
    if ($env:OA_REMOTE_INSTANCE) { $daemonArgs += @("--instance", $env:OA_REMOTE_INSTANCE) }
    if ($env:OA_REMOTE_DATA_HOME) { $daemonArgs += @("--data-home", $env:OA_REMOTE_DATA_HOME) }
    if ($env:OA_REMOTE_DEVICE_CODE) { $daemonArgs += @("--device-code", $env:OA_REMOTE_DEVICE_CODE) }
    if ($env:OA_REMOTE_BASH_TIMEOUT_SEC) { $daemonArgs += @("--bash-timeout-sec", $env:OA_REMOTE_BASH_TIMEOUT_SEC) }

    if ($env:OA_REMOTE_ENABLE_BASH -eq "1") { $daemonArgs += @("--enable-bash") }

    $remoteArgList = @(
      "run",
      "--manifest-path", (Join-Path $RootDir "remote_daemon\\Cargo.toml"),
      "--"
    ) + $daemonArgs

    Start-LoggedProcess -Name "remote_daemon" -FilePath "cargo" -ArgumentList $remoteArgList `
      -StdoutLog (Join-Path $logDir "remote_daemon.log") -StderrLog (Join-Path $logDir "remote_daemon.err.log")
  }

  Write-Host ("[dev-up] started: {0} process(es). Ctrl-C to stop." -f $services.Count)

  if ($cmdTokens.Count -gt 0) {
    Write-Host ("[dev-up] running command: {0}" -f ($cmdTokens -join " "))

    $exe = [string]$cmdTokens[0]
    $exeArgs = @()
    if ($cmdTokens.Count -gt 1) { $exeArgs = @($cmdTokens[1..($cmdTokens.Count - 1)]) }

    $cmdProc = Start-Process -FilePath $exe -ArgumentList $exeArgs -WorkingDirectory $RootDir -NoNewWindow -Wait -PassThru
    exit $cmdProc.ExitCode
  }

  if ($services.Count -eq 0) {
    Write-Host "[dev-up] nothing to run (all services disabled)."
    exit 0
  }

  while ($true) {
    $exitedSvc = $null
    foreach ($svc in $services) {
      if ($svc.Process.HasExited) { $exitedSvc = $svc; break }
    }

    if ($null -ne $exitedSvc) {
      Write-Host ("[dev-up] process exited: {0} (exit {1})" -f $exitedSvc.Name, $exitedSvc.Process.ExitCode)

      if ($exitedSvc.Name -eq "remote_daemon" -and $services.Count -gt 1) {
        Write-Host "[dev-up] continuing: proxy/media still running."
        Write-Host "[dev-up] hint: remote daemon requires a reachable IRC server."
        Write-Host "[dev-up] hint: if you don't need it, run: pwsh -NoProfile -File dev-up.ps1 --no-daemon"
        Write-Host "[dev-up] hint: otherwise set OA_IRC_HOST/OA_IRC_PORT and ensure the server is running."
        Write-Host "[dev-up] hint: see .dev/logs/remote_daemon.err.log for details."

        $services = @($services | Where-Object { $_.Name -ne "remote_daemon" })
        if ($services.Count -eq 0) { exit $exitedSvc.Process.ExitCode }
      } else {
        exit $exitedSvc.Process.ExitCode
      }
    }

    Start-Sleep -Milliseconds 250
  }
} finally {
  foreach ($svc in $services) {
    Stop-ServiceProcess $svc
  }
}
