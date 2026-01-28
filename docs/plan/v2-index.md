# v2 Index — OpenAgentic RPG Demo (Godot 4)

## Vision (v2)

Make the project feel like a **real game** (RPG Maker-style) while keeping `addons/openagentic/` runtime-first and reusable:

- A playable **top-down 2D** scene with a Player you can move around.
- Walk up to an NPC, see an **interaction prompt** (“Press E”), press to start talking.
- A **bottom dialogue box UI** with NPC name + streaming text (SSE `assistant.delta`) and a player input line.
- Keep using the existing persistence model:
  - per-save shadow workspace under `user://openagentic/saves/<save_id>/...`
  - per-NPC continuous session in JSONL

## Milestones (facts panel)

1. **RPG demo scene (movement + collisions):** Player + at least 1 NPC placed in a small map. (done; placeholder visuals)
2. **Interact & dialogue state machine:** proximity → prompt → talk mode → exit. (done)
3. **Dialogue UI (RPG Maker style):** bottom panel + speaker name + input; streams text. (done)
4. **Asset pack integrated:** Kenney CC0 sprites/tiles included with attribution docs. (todo)
5. **Smoke test:** headless script loads RPG scene and verifies required nodes/scripts exist. (done)

## Plans (v2)

- `docs/plan/v2-rpg-demo.md`

## Definition of Done (DoD)

- You can press Play and **walk around**.
- Approaching the NPC shows a prompt; pressing **E** opens the dialogue UI.
- Sending a message streams NPC output into the dialogue UI (uses the existing proxy + SSE path).
- NPC conversation persists under the save slot (same behavior as v1), and reopening the game continues the conversation.

## Verification (local)

Manual:

- Start proxy: `OPENAI_API_KEY=... node proxy/server.mjs`
- Run the project in Godot (GUI), walk to the NPC, press `E`, talk, observe streaming.

Headless smoke test (when using a local Godot CLI):

- `godot4 --headless --script tests/test_demo_rpg_smoke.gd`

## Known gaps (v2 backlog)

- Typewriter effect + “skip” behavior.
- Speech bubbles above NPCs (optional).
- Multiple NPCs + quest/state tools.
- Automatic context compacting / summarization policies.
