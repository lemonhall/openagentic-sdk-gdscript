# v48 — Dialogue: Session Log Size + One-Click Clear

## Goal

When talking to NPCs, the persisted session event log (`events.jsonl`) can silently grow large or preserve unwanted state, leading to long debugging sessions.

Add two small UI affordances to make this visible and actionable:

- show current `events.jsonl` size in the dialogue overlay header
- add a one-click “clear log” button to truncate that file for the current NPC

## Scope

In scope:

- `DialogueOverlay` header shows `events.jsonl=<size>`
- A “clear log” button truncates `user://openagentic/saves/<save_id>/npcs/<npc_id>/session/events.jsonl`
- Clearing also clears the currently displayed chat bubbles (so UI matches the persistent state)
- Button is disabled while the dialogue is busy/streaming

Out of scope:

- Changing runtime/tool behavior
- Clearing NPC summary (`memory/summary.txt`) or other save artifacts
- Any changes to v46 workspace decorations work

## Acceptance

1) Opening dialogue for an NPC shows an `events.jsonl=<size>` indicator in the header.
2) Clicking “clear log” truncates the file to 0 bytes and updates the indicator accordingly.
3) A regression test covers both the indicator and the clear action.

## Files

Modify:

- `vr_offices/ui/DialogueOverlay.tscn`
- `vr_offices/ui/DialogueOverlay.gd`
- `vr_offices/core/dialogue/VrOfficesDialogueController.gd`
- `tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd`

Add:

- (if generated) `vr_offices/ui/DialogueOverlay.tscn.uid`

## Steps (塔山开发循环)

1) **Red**: extend `test_vr_offices_dialogue_ui.gd` to assert:
   - header includes a size label and clear button
   - size reflects a known `events.jsonl` file length
   - pressing clear truncates the file and updates the label
2) **Green**: implement UI nodes + minimal logic:
   - pass `save_id` into `DialogueOverlay.open(..., save_id)`
   - compute `events.jsonl` size via `OAPaths.npc_events_path`
   - clear by truncating the file
3) **Verify**:

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd
scripts/run_godot_tests.sh --suite vr_offices
```
