# Agent Notes (OpenAgentic Godot)

## Running tests (WSL2 + Linux Godot) — recommended

If WSL interop to a Windows `.exe` is flaky (or prompts too much), run tests using a **Linux** Godot binary.

Important: this environment may not allow writing to your real `$HOME`, so set `HOME`/`XDG_*` to a writable temp dir (otherwise Godot may crash when creating `user://`).

Preferred setup: use the pre-extracted Linux Godot binary:

```bash
export GODOT_LINUX_EXE=/home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64
"$GODOT_LINUX_EXE" --version
```

Fallback (extract from zip if you don't have a ready binary):

```bash
mkdir -p /tmp/godot-4.6
unzip -o /home/lemonhall/Godot_v4.6-stable_linux.x86_64.zip -d /tmp/godot-4.6
chmod +x /tmp/godot-4.6/Godot_v4.6-stable_linux.x86_64
/tmp/godot-4.6/Godot_v4.6-stable_linux.x86_64 --version
```

Run the full test suite:

```bash
export GODOT_LINUX_EXE=${GODOT_LINUX_EXE:-/home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64}
export HOME=/tmp/oa-home
export XDG_DATA_HOME=/tmp/oa-xdg-data
export XDG_CONFIG_HOME=/tmp/oa-xdg-config
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

for t in tests/test_*.gd; do
  echo "--- RUN $t"
  timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script "res://$t"
done
```

Run a single test:

```bash
export GODOT_LINUX_EXE=${GODOT_LINUX_EXE:-/home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64}
export HOME=/tmp/oa-home
export XDG_DATA_HOME=/tmp/oa-xdg-data
export XDG_CONFIG_HOME=/tmp/oa-xdg-config
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/test_sse_parser.gd
```

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

Avoid hung tests (per-test timeout):

```bash
GODOT_TEST_TIMEOUT_SEC=120 scripts/run_godot_tests.sh
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

Avoid hung tests (per-test timeout):

```powershell
$env:GODOT_TEST_TIMEOUT_SEC = "120"
scripts\\run_godot_tests.ps1
```

## VR Offices (3D demo)

Kenney Mini Characters setup:

```bash
scripts/setup_kenney_mini_characters.sh
```

Main scene:

- `res://vr_offices/VrOffices.tscn`
