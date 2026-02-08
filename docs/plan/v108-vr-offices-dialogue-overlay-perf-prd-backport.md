# v108 — Docs: PRD backport for dialogue overlay log I/O performance

## Problem

我们已经在实现层面修复了“NPC 双击对话 overlay 出现前卡顿”的问题（根因：主线程读取/解析 `events.jsonl`）。但如果 PRD 不写死这个约束，后续任何功能（多媒体消息、会议室群聊、参与者名单等）都可能在无意间把同步日志 I/O 又塞回到 open-path，导致回归。

## Scope

- 把“打开 overlay 的同帧禁止主线程日志 I/O”的约束回落到 PRD（稳定口径）。
- 把与 `events.jsonl` 相关的硬上限（tail-scan 4MiB / 64KiB chunk / 200 items / 24 render batch）写成可验证的 Explicit Limits。
- 在多媒体 PRD 中加上性能 PRD 的交叉引用，避免各自为政。

## Non-scope

- 不改现有实现（本 slice 是文档与追溯）。
- 不解决 repo 全量 doc hygiene（现有历史 plan 还未全面补齐 PRD Trace）。

## PRD Trace

PRD: `docs/prd/2026-02-08-vr-offices-dialogue-overlay-log-io-performance.md`

- REQ-001 / REQ-006 → `vr_offices/ui/DialogueOverlay.gd`（open 当帧 placeholder + 次帧更新 size） + `tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd`
- REQ-002 / REQ-003 / REQ-004 → `vr_offices/ui/DialogueOverlay.gd`（threaded tail-scan job） + `tests/projects/vr_offices/test_vr_offices_per_npc_history.gd`
- REQ-005 → `vr_offices/ui/DialogueOverlay.gd`（incremental render） + `tests/projects/vr_offices/test_vr_offices_dialogue_history_incremental_render.gd`

## Acceptance (Hard DoD)

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd -TimeoutSec 240` → PASS
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_per_npc_history.gd -TimeoutSec 240` → PASS
- `rg -n "No Main-thread Log I/O" docs/prd/2026-02-08-vr-offices-dialogue-overlay-log-io-performance.md` → match

