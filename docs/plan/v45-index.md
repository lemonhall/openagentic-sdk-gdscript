<!--
  v45 — VR Offices: System prompt must not hide RemoteBash
-->

# v45 — VR Offices: System Prompt Tool List Is Dynamic (RemoteBash-Aware)

## Vision (this version)

- Remove a common operator confusion / model self-report bug:
  - The VR Offices system prompt must not hardcode a tool list that omits desk-bound tools like `RemoteBash`.
- Keep the rule we want:
  - When asked “你有哪些工具/能力”，NPC should list only tools it can currently see/call and never invent tools.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | Prompt guidance | System prompt describes tools as dynamic and mentions `RemoteBash` as a desk-bound example | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_system_prompt_remote_bash_mentioned.gd` | done |

## Plan Index

- `docs/plan/v45-vr-offices-system-prompt-remote-bash.md`

## Evidence

Green:

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_system_prompt_remote_bash_mentioned.gd` (PASS)
- `scripts/run_godot_tests.sh --suite vr_offices` (PASS)
