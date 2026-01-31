## Why

The desk right-click context menu includes a Chinese-only item (“绑定设备码…”) which is inconsistent with the rest of the (English) VR Offices UI and is jarring for non-Chinese users. Additionally, the “bind device code” dialog is currently too narrow, causing text clipping and making the flow hard to use.

## What Changes

- Change the desk RMB context menu label from “绑定设备码…” to an English label (e.g., “Bind Device Code…”).
- Increase the width (or minimum width) of the bind-device-code dialog so its text and controls are readable without clipping.
- Keep the behavior the same (device code validation/persistence/channel logic unchanged).
- No internationalization work in this change; strings will be hard-coded English for now.

## Capabilities

### New Capabilities

- `vr-offices-bind-device-code-ui`: Desk context menu + bind-device-code dialog has consistent English copy and a readable layout (no clipped text at default scale).

### Modified Capabilities

## Impact

- Affected code will likely be limited to `vr_offices/ui/*` (desk context menu + the bind-device-code dialog UI).
- Documentation and any user-facing strings referencing “绑定设备码” may need minor updates to match the new English label.
