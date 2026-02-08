Param(
  [Parameter(Mandatory = $true)][string]$SaveId,
  [string]$NpcId = "",
  [switch]$NoBackup
)

$ErrorActionPreference = "Stop"

function Resolve-SaveRoot([string]$sid) {
  $appData = $env:APPDATA
  if ([string]::IsNullOrWhiteSpace($appData)) {
    throw "APPDATA is not set; cannot locate Godot user data directory."
  }
  # project.godot: config/name="openagentic-sdk-gdscript"
  $root = Join-Path $appData "Godot\app_userdata\openagentic-sdk-gdscript\openagentic\saves\$sid"
  return $root
}

function Compact-EventsFile([string]$path, [string]$npcFilter, [bool]$noBackup) {
  # Optional NPC filter (only matches npc/<id>/session/events.jsonl).
  if (-not [string]::IsNullOrWhiteSpace($npcFilter)) {
    $needle = "\npcs\$npcFilter\session\events.jsonl"
    if ($path -notlike "*$needle") {
      return
    }
  }

  $tmp = "$path.tmp"
  $removed = 0
  $kept = 0

  $in = $null
  $out = $null
  try {
    $in = [System.IO.StreamReader]::new($path, [System.Text.Encoding]::UTF8, $true)
    $out = [System.IO.StreamWriter]::new($tmp, $false, [System.Text.Encoding]::UTF8)

    while ($true) {
      $line = $in.ReadLine()
      if ($null -eq $line) { break }
      if ($line -match '"type"\s*:\s*"assistant\.delta"') {
        $removed++
        continue
      }
      $out.WriteLine($line)
      $kept++
    }
  } finally {
    if ($out) { $out.Dispose() }
    if ($in) { $in.Dispose() }
  }

  if ($removed -eq 0) {
    Remove-Item -Force $tmp -ErrorAction SilentlyContinue
    return
  }

  $bak = "$path.bak"
  if (-not $noBackup) {
    if (Test-Path $bak) {
      $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
      $bak = "$path.$stamp.bak"
    }
    Move-Item -Force $path $bak
  } else {
    Remove-Item -Force $path
  }
  Move-Item -Force $tmp $path

  Write-Host ("COMPACT: {0}  removed={1} kept={2}" -f $path, $removed, $kept)
}

$saveRoot = Resolve-SaveRoot $SaveId
if (-not (Test-Path $saveRoot)) {
  throw ("Save root not found: {0}`nTip: verify SaveId and that you ran the game at least once." -f $saveRoot)
}

$files = Get-ChildItem -Path $saveRoot -Recurse -Filter "events.jsonl" -File |
  Where-Object { $_.FullName -like "*\session\events.jsonl" } |
  Sort-Object FullName

if ($files.Count -eq 0) {
  Write-Host ("No events.jsonl found under {0}" -f $saveRoot)
  exit 0
}

foreach ($f in $files) {
  Compact-EventsFile $f.FullName $NpcId ([bool]$NoBackup)
}

