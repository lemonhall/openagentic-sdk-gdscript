# VR Offices: NPC Personal Skill Management (“Skills”) PRD

## Vision

Provide a “personal skills management” screen for each NPC:

- Entry point lives in the NPC chat window (Dialogue overlay) as a top-right **Skills** button.
- The screen looks/feels like classic RPG skill management: a large UI with the NPC’s animated 3D model on the right, and skill “cards” on the left.
- The screen also shows an LLM-generated “capability summary” for the NPC based on the skills they currently have, so managers can quickly review the NPC’s skill combination.

## Terminology

- **NPC Skills Dir**: `user://openagentic/saves/<save_id>/npcs/<npc_id>/workspace/skills/`
- **Learned skill**: a directory under NPC Skills Dir containing `SKILL.md` (same structure as library skills).
- **Skill card**: a visual tile representing a learned skill (name/desc/thumbnail placeholder).
- **Capability summary**: a short paragraph describing what the NPC is good at, derived from the set of learned skills.

## UX Overview

1) Player opens an NPC chat window (Dialogue overlay).
2) Player clicks **Skills** (top-right button in the chat header).
3) A large overlay opens:
   - **Left**: scrollable grid/list of skill cards (initial MVP = flat list).
   - **Right**: the NPC’s 3D model preview (idle animation playing) in a mini-world (same rendering isolation logic as Teach popup).
   - **Top/Left** (or near the card list): the NPC’s capability summary + a refresh affordance (MVP = optional).

## Requirements

### REQ-001 — Entry point: Skills button in NPC chat window

In `vr_offices/ui/DialogueOverlay.tscn` (and script):

- Add a **Skills** button in the header area (top-right vicinity).
- Button behavior:
  - Enabled only when the Dialogue overlay is bound to a specific NPC (has `save_id` + `npc_id` context).
  - Opens the NPC Skills overlay when pressed.

### REQ-002 — New Skills overlay screen (large, closable)

- Add a new overlay scene (name TBD, e.g. `NpcSkillsOverlay`).
- Overlay must:
  - Accept `save_id` + `npc_id` (and optionally `display_name`, `model_path`) as open parameters.
  - Be dismissible via Close button and Esc.
  - Be larger than the Teach popup (MVP: use the same “modal overlay” pattern as other VR Offices overlays).

### REQ-003 — Right side: NPC 3D preview (Teach-popup-like)

- Render the NPC model on the right using a `SubViewport` with an isolated world (`own_world_3d = true`).
- Play a looped idle animation when available (reuse the Teach popup preview logic/heuristics).
- Headless safety:
  - In headless/server mode the preview is hidden/disabled and must not crash.

### REQ-004 — Left side: learned skills shown as cards (flat list MVP)

- Discover learned skills from the NPC Skills Dir.
  - A learned skill is any directory containing `SKILL.md`.
- For this milestone, treat **learned == equipped**:
  - all skills under NPC Skills Dir are considered “equipped” and participate in the capability summary.
- For each skill:
  - Parse `SKILL.md` frontmatter to extract at least `name` and `description`.
  - Show as a card in a scrollable list/grid.
- Sorting/filtering:
  - MVP: sort by `name`.
  - Optional MVP: simple text filter (match name/description).

### REQ-005 — Card UI is thumbnail-ready (image generation deferred)

- Each card must have a reserved thumbnail area.
- MVP thumbnail behavior:
  - Show a placeholder image/icon.
  - No image-generation API calls in this milestone.
- Future affordance: store a per-skill thumbnail once generated (path + caching defined later).

### REQ-006 — Capability summary generation (LLM-backed, cached)

Given the NPC’s current learned skills (names + descriptions), generate a short “resume intro” style paragraph:

- Length: **≤ 150 Chinese characters** (or ≤ 150 chars in the selected language).
- Tone: “human resume intro” style (manager-facing), describing the NPC’s strengths based on the skills set.
- Language: prefer current culture (e.g. `zh-CN` save culture) if available; otherwise English.
- Behavior:
  - On overlay open: show the cached summary immediately (if present).
  - If missing/stale: generate asynchronously and update UI when ready.
  - Provide a manual “Refresh summary” action (MVP can be a button).
- Reliability:
  - Retry up to **3 times** on transient failures; record the last error for debugging.
- Caching:
  - Store the summary keyed by an **input hash** of the learned skill set (stable ordering + normalized text).
  - Only regenerate when the input hash changes (or when user presses refresh).

### REQ-007 — Deferred regeneration when teaching a new skill

When a skill is successfully taught to an NPC (Teach popup flow):

- Mark the NPC capability summary as stale.
- Immediately enqueue a background regeneration job (do not block the teaching UI).
- On next open of the Skills overlay, it should either:
  - show the latest cached summary (if regeneration already completed), or
  - show “updating…” and run generation.

### REQ-008 — Persistence: where the capability summary lives

Persist per-NPC summary data under the existing per-NPC save/session storage:

- Recommended storage: `user://openagentic/saves/<save_id>/npcs/<npc_id>/session/meta.json`
- Fields (MVP suggestion):
  - `skills_profile_summary` (string)
  - `skills_profile_input_hash` (string)
  - `skills_profile_updated_at_unix` (int)
  - `skills_profile_last_error` (string, optional)

### REQ-009 — Uninstall learned skills (delete from NPC workspace)

- The Skills overlay supports uninstalling a learned skill.
- Uninstall behavior:
  - Remove `user://openagentic/saves/<save_id>/npcs/<npc_id>/workspace/skills/<skill_name>/` recursively.
  - After uninstall, the skill card list updates immediately.
  - Mark the capability summary as stale and enqueue regeneration (as in REQ-007).

### REQ-010 — Automated tests (headless-safe; no real network)

Add automated tests covering:

1) **Dialogue entry**: Dialogue overlay contains the Skills button and it is enabled/disabled based on NPC context.
2) **Overlay render**: Skills overlay instantiates headlessly, and the 3D preview area is safely disabled in headless mode.
3) **Skill discovery/parsing**: Given a temporary `user://` NPC Skills Dir with a minimal valid `SKILL.md`, the overlay loads and renders the expected number of cards.
4) **Summary caching gate**: summary generation is skipped when input hash is unchanged; refresh forces regeneration.

Tests must not depend on external network access; LLM calls must be stubbed/mocked or exercised only via cached-path behavior.

## Non-Goals (for this milestone)

- Skill tree visualization, prerequisites, leveling, or progression mechanics.
- Thumbnail image generation (planned later).
- Editing skills, uninstalling skills, or per-skill enable/disable toggles.
- Any expansion of `demo_rpg/`.

## Open Questions

1) Where should skill thumbnails be stored:
   - inside each skill directory (e.g. `.../skills/<name>/thumbnail.png`), or
   - in a per-NPC cache folder (e.g. `.../workspace/skill_thumbnails/<name>.png`)?
