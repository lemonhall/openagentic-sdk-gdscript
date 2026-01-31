## Context

VR Offices provides a desk right-click (RMB) context menu that includes a “bind device code” action and a modal/popup to enter the code. Today:

- The context-menu label is Chinese-only (“绑定设备码…”), while the rest of the VR Offices UI is primarily English.
- The device-code popup is fixed-size and is currently too narrow for its contents at typical UI scale, causing text clipping.

This change is intentionally small and UI-focused: improve copy consistency and make the dialog readable without changing any device-code logic (validation, persistence, channel derivation).

## Goals / Non-Goals

**Goals:**

- Replace the desk RMB context menu label with an English label: “Bind Device Code…”.
- Increase the bind-device-code popup width (and keep its initial scene size consistent) so text is not clipped at default UI scale.
- Keep the interaction and underlying behavior unchanged (same signals, device code rules, persistence, and channel naming).

**Non-Goals:**

- Full internationalization/localization (no TranslationServer integration in this change).
- Changing device code validation/canonicalization rules.
- Any broader UI redesign of VR Offices overlays.

## Decisions

- **Copy change (hard-coded English for now):**
  - Update `vr_offices/ui/DeskOverlay.gd` to add the context menu item with the English label “Bind Device Code…”.
  - Update any other user-facing references to “绑定设备码” in the VR Offices UI copy where it would confuse the operator (e.g., error/help strings), but avoid touching non-UI logic.

- **Popup sizing:**
  - Treat `DeskOverlay.gd`’s `DEVICE_POPUP_SIZE` as the single source of truth for runtime sizing (it is used by `popup_centered(...)`).
  - Increase `DEVICE_POPUP_SIZE.x` to a larger value that fits the existing hint text without clipping at default scale.
  - Keep `DeskOverlay.tscn`’s initial `DevicePopup` size in sync with the runtime constant so the scene looks correct in the editor as well.

## Risks / Trade-offs

- **Hard-coded English strings now** → Mitigation: keep all copy changes localized to the overlay; future i18n can replace these with translation keys.
- **Larger popup could be too wide on small viewports** → Mitigation: keep the increase modest; if needed, clamp the requested size to the current viewport in code.
