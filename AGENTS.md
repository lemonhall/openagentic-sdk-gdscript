# Agent Notes (OpenAgentic Godot)

## Running tests (WSL2 + Windows Godot)

If you are working inside WSL2 but have a Windows Godot executable, use the wrapper script:

```bash
scripts/run_godot_tests.sh
```

Override the executable path if needed:

```bash
GODOT_WIN_EXE="/mnt/e/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe" scripts/run_godot_tests.sh
```

Run a single test:

```bash
scripts/run_godot_tests.sh --one tests/test_sse_parser.gd
```

Notes:
- The script uses `wslpath` to convert Linux paths to Windows paths.
- This runs a Windows `.exe` via WSL interop; some environments may require elevated permissions.

## VR Offices (3D demo)

Kenney Mini Characters setup:

```bash
scripts/setup_kenney_mini_characters.sh
```

Main scene:

- `res://vr_offices/VrOffices.tscn`
