# v71 VR Offices: NPC personal skill management

## Goal

Implement the MVP “Skills” overlay for an NPC:

- Entry from the Dialogue overlay header (REQ-001).
- Left side skill cards from the NPC workspace skills dir; support uninstall (REQ-004, REQ-009).
- Right side NPC 3D preview mini-world playing idle animation (REQ-003).
- Capability summary generated via OpenAgentic provider, cached in per-NPC `meta.json`, retried up to 3 times, ≤150 chars (REQ-006..REQ-008).
- Teaching a skill enqueues a background summary regeneration (REQ-007).

## PRD Trace

- REQ-001..REQ-010 in `docs/prd/2026-02-05-vr-offices-npc-skill-management.md`

## Scope

### In scope (v71)

- Add Skills button to `DialogueOverlay` header and signal up to `VrOffices` to open the overlay.
- New overlay scene + script:
  - skill list/cards + uninstall
  - preview mini-world (headless-safe)
  - summary text area + refresh
- New service node to queue/regenerate summary in background with retry + cache.
- Hook teach flow to enqueue regeneration when teaching succeeds.
- Headless-safe automated tests with stubbed provider.

### Out of scope (v71)

- Skill tree visualization / prerequisites / leveling.
- Thumbnail generation and storage (cards are only “thumbnail-ready”).
- Any changes under `demo_rpg/`.

## Acceptance (DoD)

1) Dialogue overlay shows a header Skills button; it is only usable when `open()` has set NPC context.
2) Skills overlay opens for an NPC and:
   - lists learned skills discovered under `OAPaths.npc_skills_dir(save_id, npc_id)` as cards (name+desc + placeholder thumbnail area).
   - supports uninstall: skill directory removed and card list updates.
3) Skills overlay right panel shows NPC 3D preview that continues playing idle animation (non-headless); in headless it is hidden and must not crash.
4) Capability summary:
   - stored in `OAPaths.npc_meta_path(save_id, npc_id)` under keys:
     - `skills_profile_summary`, `skills_profile_input_hash`, `skills_profile_updated_at_unix`, `skills_profile_last_error`
   - regenerated only when input hash changes (unless forced refresh)
   - uses OpenAgentic provider; retries up to 3 times on failures
   - final text trimmed and clamped to ≤150 chars
5) Teach popup: after a successful teach, summary regeneration is enqueued without blocking UI.
6) Tests:
   - `test_vr_offices_dialogue_ui.gd` updated to assert Skills button exists.
   - New `test_vr_offices_npc_skills_overlay.gd` covers list/uninstall + summary cache gate using a fake provider (no network).

## Files

Create/modify (expected):

- `vr_offices/ui/DialogueOverlay.tscn`
- `vr_offices/ui/DialogueOverlay.gd`
- `vr_offices/VrOffices.tscn`
- `vr_offices/VrOffices.gd`
- `vr_offices/ui/VrOfficesTeachSkillPopup.gd` (enqueue summary regen on success)
- `vr_offices/ui/VrOfficesNpcSkillsOverlay.tscn` (new)
- `vr_offices/ui/VrOfficesNpcSkillsOverlay.gd` (new)
- `vr_offices/core/skills/VrOfficesNpcSkillsService.gd` (new)
- `tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd`
- `tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd` (new)

## Steps (塔山开发循环)

### 1) TDD Red

- Update `tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd` to require the Skills button node exists.
- Add `tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd` that:
  - creates an NPC skill directory under a temporary save id with a minimal `SKILL.md`
  - opens the overlay and asserts card count and names
  - uninstalls a skill and asserts the directory is deleted and cards refresh
  - injects a fake OpenAgentic provider; asserts summary generation writes to meta.json and is skipped when hash unchanged

Run (expect fail until implemented):

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd`
- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd`

### 2) TDD Green

- Implement `VrOfficesNpcSkillsOverlay` UI and wiring.
- Implement `VrOfficesNpcSkillsService` job queue + summary generation + retry + caching.
- Wire DialogueOverlay Skills button → VrOffices handler → open overlay.
- Wire teach popup success → service enqueue.

Run:

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd`
- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_npc_skills_overlay.gd`

### 3) Refactor (still green)

- Extract shared helpers if needed (hashing, meta.json read/write, preview setup) to keep files < ~200 LOC where practical.
- Ensure headless guards are consistent across overlay + service.

### 4) Review

- Confirm traceability: each PRD REQ touched has code + tests or is explicitly deferred.
- Update `docs/plan/v71-index.md` evidence section with actual PASS output commands.

## Risks / Notes

- Godot “threading” is not safe for scene tree/HTTPClient; implement background as an async queued job (non-blocking UI) rather than OS threads.
- Ensure tool schema discipline is unaffected (this feature should not add tool schemas).

