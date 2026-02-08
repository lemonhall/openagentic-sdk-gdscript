<!--
  PRD — VR Offices: Dialogue Overlay Performance (No Main-thread events.jsonl I/O)
  Date: 2026-02-08
-->

# PRD — VR Offices: Dialogue Overlay Performance (No Main-thread Log I/O)

## Vision

玩家双击 NPC 打开对话（`DialogueOverlay`）必须“秒开”：无论该 NPC 的 `events.jsonl` 多大，都不能在 UI 出现前产生 1–2s 的卡顿。

核心原则：

- **交互路径优先**：Overlay 先可见，再补齐历史/大小信息。
- **主线程零日志 I/O**：`DialogueOverlay.open()` 所在帧禁止读取/解析 `events.jsonl`（否则 UI 可能连第一帧都画不出来）。
- **只回放“干净历史”**：UI 只需要 `user.message` / `assistant.message`，其它事件（包括 streaming delta）只能用于调试，不得拖慢交互。

## Non-goals（本期不做）

- 不做“全量历史分页/向上滚动加载更老消息”（可作为后续增量）。
- 不改变 session store 的数据结构（仍以 `events.jsonl` 作为审计/回放日志）。
- 不要求把 `events.jsonl` 改成“只存 message”（允许保留其它事件，但 UI 必须过滤 + 异步）。

## Background / Current State

- VR Offices 的每个 NPC 会把会话事件写入 `user://openagentic/saves/<save_id>/npcs/<npc_id>/session/events.jsonl`（简称 `events.jsonl`）。
- `DialogueOverlay` 打开时需要显示最近的对话气泡；历史来自对 `events.jsonl` 的重建。
- 用户手动清理 logs 后 overlay 秒开；logs 变大后 overlay 出现前卡 1–2s ——根因是 **主线程磁盘 I/O / JSONL 解析阻塞了渲染**。

## Requirements（带 Req ID）

### Open path (zero main-thread log I/O)

- **REQ-001** `DialogueOverlay.open()` 必须在同一帧把 overlay 显示出来，并且该帧 **不得**：
  - 打开/seek/读取 `events.jsonl`（包括只为取 size 而打开文件）。
  - 解析 JSONL。
  - 在 UI 线程做大规模节点构建（历史气泡必须分批渲染）。
  - 允许：只写 UI 占位，例如 `events.jsonl=…`。

### History load (background tail scan)

- **REQ-002** Overlay 打开后，历史加载必须在后台 job/线程中完成；主线程只轮询结果并更新 UI。
- **REQ-003** 历史重建必须采用 **tail-scan**，并且只提取：
  - `type == "user.message"` 的 `text`
  - `type == "assistant.message"` 的 `text`
  - 其它类型（例如 `assistant.delta`）必须忽略（可留作调试，但不得进入 UI 的“干净历史”）。

### Hard bounds (防反作弊：日志再大也不许卡)

- **REQ-004** tail-scan 必须有硬上限（防止“日志爆炸后又回到全量扫描”）：
  - 每次最多返回 **200** 条 UI history items（最新优先）。
  - 从文件尾部向前扫描最多 **4 MiB**（扫描不够也接受：显示能找到的最新消息即可）。
  - 每次读取 chunk 大小为 **64 KiB**（实现细节可变，但上限必须能验证）。

### Rendering (incremental bubble construction)

- **REQ-005** UI 气泡必须分批渲染（避免一次性 instantiate 大量节点），每批建议上限 **24** 条。

### UX / Observability

- **REQ-006** Overlay 必须展示当前 `events.jsonl` 的大小（用于定位“日志膨胀”问题），但大小更新必须异步：
  - 打开当帧显示 `events.jsonl=…`
  - 次帧或后台 job 完成后更新为 `events.jsonl=<bytes>`（并可提供 tooltip 显示绝对路径）

## Explicit Limits（v1 约束，必须可验证）

建议作为“最低硬阈值”（和实现对齐）：

- `history.max_items = 200`
- `tail.max_scan_bytes = 4 MiB`
- `tail.chunk_bytes = 64 KiB`
- `render.batch_size = 24`

## Verification Strategy（自动化）

目标：不用肉眼看 UI，也能回归验证“秒开 + 异步历史/大小”不会回归。

必须至少覆盖：

1) **打开当帧 overlay 可见**，且 size label 没有同步显示 bytes（证明不是同步读文件）。
2) **历史最终能加载出来**（异步完成后消息可见）。

推荐命令（Windows PowerShell）：

- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_ui.gd -TimeoutSec 240`
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_per_npc_history.gd -TimeoutSec 240`
- （可选更强覆盖）`pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_dialogue_history_incremental_load.gd -TimeoutSec 240`

## Acceptance (Global DoD)

以下每条都必须能被测试/命令二元验证：

1) `DialogueOverlay.open()` 当帧可见；并且 size label 在次帧更新（不允许同步显示 bytes）。
2) 对话历史在后台加载完成后可见，且 UI 不冻结。
3) 日志再大（包含 delta/噪声事件）时，仍只读取尾部受限范围，不回退到全量扫描。

