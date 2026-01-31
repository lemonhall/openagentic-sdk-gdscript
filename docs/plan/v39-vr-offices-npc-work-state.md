# v39 — VR Offices NPC Work State (Desk Binding)

## Goal

When an NPC becomes desk-bound, it enters a stable “working” state (distinct animation, no wandering). When it becomes unbound, it returns to random wandering. If the user commands the NPC to move away from the desk, the NPC should not enter the old “wait for work (60s)” mode afterward; it should resume wandering.

## Scope

In scope:

- Add `on_desk_bound(desk_id)` / `on_desk_unbound(desk_id)` on `Npc.gd`.
- Add a “work” animation selection with robust fallback (prefer `work/typing/interact-*`, else idle).
- In the movement state machine:
  - If desk-bound and not moving → play work animation, stand still.
  - If a move command was issued while desk-bound → skip post-move waiting and resume wandering.

Out of scope:

- Facing the desk / IK alignment.
- Any new job/task dispatch system.

## Acceptance

- Bound → NPC stops wandering and plays work animation.
- Unbound → NPC resumes wandering.
- Move command issued while bound → after reaching destination, NPC resumes wandering (no 60s wait).

## Files

- Modify: `vr_offices/npc/Npc.gd`
- Test: `tests/projects/vr_offices/test_vr_offices_desk_npc_bind_indicator_smoke.gd`

## Steps (塔山开发循环)

### 1) Red

- Extend the desk bind indicator smoke test to assert:
  - `on_desk_bound` is called (NPC reports bound desk id).
  - Unbind returns to wandering.
  - “move away after bound” skips waiting-for-work.

Run:

```bash
timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script res://tests/projects/vr_offices/test_vr_offices_desk_npc_bind_indicator_smoke.gd
```

### 2) Green

- Implement the minimal state fields + methods + movement logic in `Npc.gd`.
- Keep behavior unchanged for normal move-to (not desk-related).

