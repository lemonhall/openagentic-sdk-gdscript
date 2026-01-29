# Agent Notes (OpenAgentic Godot)

## Running tests (WSL2 + Windows Godot)

If you are working inside WSL2 but have a Windows Godot executable, use the wrapper script:

```bash
scripts/run_godot_tests.sh
```

Override the executable path if needed:

```bash
GODOT_WIN_EXE="/mnt/e/Godot_v4.6-stable_win64.exe/Godot_v4.6-stable_win64_console.exe" scripts/run_godot_tests.sh
```

Run a single test:

```bash
scripts/run_godot_tests.sh --one tests/test_sse_parser.gd
```

Notes:
- The script uses `wslpath` to convert Linux paths to Windows paths.
- This runs a Windows `.exe` via WSL interop; some environments may require elevated permissions.

## Running tests (Windows PowerShell)

If WSL interop is flaky, run tests from Windows directly:

```powershell
scripts\\run_godot_tests.ps1
```

Override the executable path if needed:

```powershell
$env:GODOT_WIN_EXE = "E:\\Godot_v4.6-stable_win64.exe\\Godot_v4.6-stable_win64_console.exe"
scripts\\run_godot_tests.ps1
```

Pass extra Godot args (e.g. to debug shutdown leaks):

```powershell
scripts\\run_godot_tests.ps1 -One tests\\test_vr_offices_smoke.gd -ExtraArgs --verbose
```

## VR Offices (3D demo)

Kenney Mini Characters setup:

```bash
scripts/setup_kenney_mini_characters.sh
```

Main scene:

- `res://vr_offices/VrOffices.tscn`
