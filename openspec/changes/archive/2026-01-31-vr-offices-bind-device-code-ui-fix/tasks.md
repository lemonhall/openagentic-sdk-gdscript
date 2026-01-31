## 1. Tests (Red)

- [x] 1.1 Update/add a VR Offices test to assert the desk context menu contains an item labeled `Bind Device Code…`
- [x] 1.2 Update/add a VR Offices test to assert the bind-device-code dialog opens with width >= 640 px

## 2. UI Implementation (Green)

- [x] 2.1 Change the desk RMB context menu label in `vr_offices/ui/DeskOverlay.gd` from `绑定设备码…` to `Bind Device Code…`
- [x] 2.2 Increase the bind-device-code popup width in `vr_offices/ui/DeskOverlay.gd` (`DEVICE_POPUP_SIZE.x`) to >= 640 and keep `vr_offices/ui/DeskOverlay.tscn` `DevicePopup` initial size in sync
- [x] 2.3 Replace other operator-facing references to `绑定设备码` with English where applicable (e.g., `vr_offices/core/agent/VrOfficesRemoteTools.gd`)

## 3. Docs

- [x] 3.1 Update `remote_daemon/README.md` to match the new English label (right-click desk → `Bind Device Code…`)
- [x] 3.2 Update any relevant internal docs that reference the old Chinese label (e.g., `docs/plan/v41-*.md`)

## 4. Verification

- [x] 4.1 Run `scripts/run_godot_tests.sh --suite vr_offices`
- [x] 4.2 Confirm `rg -n \"绑定设备码\" -S vr_offices remote_daemon docs` only shows intentional historical references (or none)
