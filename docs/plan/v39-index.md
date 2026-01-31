<!--
  v39 — Desk↔NPC ground bind indicator + NPC work state + desk channel bridge
-->

# v39 — Desk↔NPC Binding (Ground Indicator) + NPC Work State

## Vision (this version)

- Each desk has a **ground “quest marker”** in front of the monitor side:
  - When an NPC stands on it → **bind** the desk to that NPC.
  - When the NPC leaves → **unbind**.
  - **One desk binds at most one NPC**; other NPCs stepping on it do not steal the binding.
  - The indicator has **idle animation** + **color change** for bound/unbound.
- When bound, the NPC enters a **working** state (distinct animation), and when unbound returns to **random wander**.
- Optional (but implemented): if the desk has an IRC link, the **desk channel becomes the NPC command channel** while bound.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Desk ground bind indicator | Indicator node + bind/unbind rules + color change | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_desk_npc_bind_indicator_smoke.gd` | todo |
| M2 | NPC work state integration | `Npc.gd` work state + unbind returns to wander + skip post-move waiting when leaving desk | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_desk_npc_bind_indicator_smoke.gd` | todo |
| M3 | Desk channel bridge (IRC) | Desk IRC PRIVMSG → OpenAgentic turn → reply back to IRC | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_desk_npc_bind_indicator_smoke.gd` | todo |

## Plan Index

- `docs/plan/v39-vr-offices-desk-npc-bind-indicator.md`
- `docs/plan/v39-vr-offices-npc-work-state.md`
- `docs/plan/v39-vr-offices-desk-channel-bridge.md`

## Evidence

- Red (expected):
  - `res://tests/projects/vr_offices/test_vr_offices_desk_npc_bind_indicator_smoke.gd` → `FAIL: Missing StandingDesk/NpcBindIndicator`

- Green (Linux Godot 4.6 headless):
  - `res://tests/projects/vr_offices/test_vr_offices_desk_npc_bind_indicator_smoke.gd` (PASS)
  - `res://tests/projects/vr_offices/test_vr_offices_desk_irc_indicator_smoke.gd` (PASS)
  - `res://tests/projects/vr_offices/test_vr_offices_standing_desk_centering.gd` (PASS)
  - `res://tests/projects/vr_offices/test_vr_offices_desk_irc_link_smoke.gd` (PASS)
  - `res://tests/projects/vr_offices/test_vr_offices_right_click_move.gd` (PASS)
