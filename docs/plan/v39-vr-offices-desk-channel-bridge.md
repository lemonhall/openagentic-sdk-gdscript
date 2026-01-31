# v39 — VR Offices Desk Channel Bridge (IRC → NPC)

## Goal

If a desk has an IRC link (`DeskIrcLink`) and is bound to an NPC, the desk IRC channel becomes the NPC’s command channel:

- Incoming `PRIVMSG` on the desk channel triggers an OpenAgentic turn for the bound NPC.
- The assistant reply is sent back to the same channel.
- Ignore messages sent by the desk’s own nick (avoid loops).

## Scope

In scope:

- Hook `DeskIrcLink.message_received` while `StandingDesk` has a `NpcBindIndicator` bound NPC.
- Resolve OpenAgentic via `/root/OpenAgentic` (no new plumbing required).
- Keep the feature inert if no OpenAgentic or no DeskIrcLink exists.
- Add a headless unit-style test using fake IRC + fake OpenAgentic nodes (no networking).

Out of scope:

- Rich IRC formatting / multi-line streaming.
- Persisting IRC↔NPC transcripts.

## Acceptance

- A `PRIVMSG` on `DeskIrcLink.get_desired_channel()` triggers `OpenAgentic.run_npc_turn(bound_npc_id, text, cb)`.
- The assistant output is sent via `DeskIrcLink.send_channel_message`.
- Messages with prefix nick == `DeskIrcLink.get_nick()` are ignored.

## Files

- Modify: `vr_offices/core/desks/VrOfficesDeskIrcLink.gd` (expose nick)
- Create/Modify: `vr_offices/furniture/DeskNpcBindIndicator.gd` (bridge logic)
- Test: `tests/projects/vr_offices/test_vr_offices_desk_npc_bind_indicator_smoke.gd`

## Steps (塔山开发循环)

### 1) Red

- Extend the smoke test to:
  - Inject a fake `DeskIrcLink` and fake `OpenAgentic`.
  - Emit a fake `PRIVMSG` and assert the fake OpenAgentic is called and a reply is sent.

### 2) Green

- Implement the bridge logic with safe guards and loop prevention.

