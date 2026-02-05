# VR Offices: Teach a shared library skill to an active NPC PRD

## Vision

From the `VendingMachineOverlay` **Library** tab (“管”), the player can select an installed (validated) shared skill and “teach” it to an **active NPC**. Teaching copies the skill directory into the NPC’s private workspace so it persists with the save slot.

This milestone focuses on **functional teaching + a non-listy NPC picker UI**. Cosmetic effects (animations, SFX, speech bubbles) are explicitly deferred.

## Terminology

- **Shared skill**: a validated skill directory under `shared/skill_library/<skill_name>/`.
- **Active NPC**: an NPC currently present/loaded in the VR Offices scene (group `vr_offices_npc`). If the scene list is not available, fallback to NPCs recorded in `vr_offices/state.json` for the save slot.
- **Teaching**: copying the shared skill directory into the NPC’s private workspace:
  - `user://openagentic/saves/<save_id>/npcs/<npc_id>/workspace/skills/<skill_name>/`

## Requirements

### REQ-001 — Library UI exposes a “Teach” action

In `vr_offices/ui/VendingMachineOverlay.tscn` Library tab:

- Replace the disabled “Assign (Later)” placeholder with an enabled `Teach` button.
- If no skill is selected or no save_id is available, teaching is blocked with a readable message.

### REQ-002 — NPC picker is arrow-based (not a list)

On `Teach` click, show a popup picker:

- Center panel shows the **currently selected NPC**.
- Left/right arrow buttons (`<` and `>`) cycle through the active NPC set.
- A `Learn`/`Teach` confirm button triggers the copy action.
- A `Cancel` button closes the popup.

### REQ-003 — “Real NPC picture” preview (best-effort MVP)

The picker shows a small preview “picture”:

- Prefer rendering a simple 3D preview from the NPC’s `model_path` into a `SubViewport`.
- If headless/server, or model load fails, fallback to a placeholder (text-only is acceptable in headless).

### REQ-004 — Teaching copies into NPC private workspace (overwrite semantics)

When confirming teach:

- Source directory is the selected shared skill’s directory.
- Destination is `OAPaths.npc_skill_dir(save_id, npc_id, skill_name)`.
- If destination already exists, **replace** it (delete then copy) so teaching can act as an update.
- Must create destination parent directories as needed.
- Must never allow path traversal / absolute paths (skill name is already validated, but still treat inputs defensively).

### REQ-005 — Testing & verification is automated

- Add an automated test that:
  - installs a shared skill in a test save slot,
  - creates a fake active NPC (in group `vr_offices_npc`),
  - triggers “Teach” and confirms it,
  - asserts the NPC’s `workspace/skills/<skill_name>/SKILL.md` exists.
- Must run offline (no network).

## Non-Goals (this milestone)

- No animations/SFX/speech bubbles (defer).
- No multi-NPC bulk teaching.
- No per-NPC “already learned” UI badges beyond basic status text.
- No changes to `demo_rpg/`.

## Persistence & Paths

- Shared library skill:
  - `user://openagentic/saves/<save_id>/shared/skill_library/<skill_name>/...`
- NPC workspace skill (taught):
  - `user://openagentic/saves/<save_id>/npcs/<npc_id>/workspace/skills/<skill_name>/...`

