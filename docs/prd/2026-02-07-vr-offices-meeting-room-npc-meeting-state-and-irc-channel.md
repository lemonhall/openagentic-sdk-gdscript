# PRD — VR Offices: Meeting Room NPC “Meeting State” + IRC Channel Group Chat

## 0) 元信息

- Topic：Meeting Room NPC 进入会议状态 + 会议室 IRC channel + 群聊分发
- Owner：OpenAgentic VR Offices
- Status：draft
- Version：v2
- Last updated：2026-02-07
- Links：
  - 相关 PRD：`docs/prd/2026-02-07-vr-offices-meeting-rooms.md`
  - 相关 PRD：`docs/prd/2026-02-07-vr-offices-meeting-room-mic-group-chat.md`
  - 计划入口（待创建）：`docs/plan/v93-index.md`

## 1) 背景与问题（Problem Statement）

当前 Meeting Room 已经能生成（矩形创建 + 持久化 + 右键删除）并具备 mic + 群聊 overlay 的入口，但缺少“**NPC 参会**”这个核心闭环：

- 玩家可以用“选中 NPC → 右键点击地面 → NPC 走到目标点并停住”的方式摆位；
- 但当目标点在会议桌周围时，NPC 没有自动进入“会议待命”状态，也没有加入会议室的群聊通道；
- 玩家通过 mic 打开的群聊 overlay 也还没有一个明确、稳定、可复用的“会议室 channel”抽象。

需要补齐：NPC 到位 → 自动入会 → 加入会议室 channel → 玩家在群聊说话 → 参会 NPC 收到并可选择回复（被点名必须回复）。

## 2) 目标（Goals）

- G1：NPC 被指令移动到会议桌附近（2m 内）并停下后，自动进入 **meeting 状态**（参会待命）。
- G2：每个 Meeting Room 有一个稳定、可推导的 **IRC channel 名称**（用于群聊与日志/工具链对齐）。
- G3：进入 meeting 状态的 NPC 会加入该 channel；玩家从 mic overlay 发送的消息会广播给所有参会 NPC。
- G4：被主持人/玩家在消息中明确点名的 NPC 必须回应；否则 NPC 可以自主决定是否回应（基于其 persona/当前任务/策略）。

## 3) 非目标（Non-goals）

- NG1：真实多人网络语音/会议系统（音频、空间语音、回声消除等）。
- NG2：会议排期/预定/座位自动分配/椅子摆放。
- NG3：复杂的自然语言点名识别（只做清晰、可预测的点名规则）。
- NG4：强一致的并发对话调度（先保证可用与可回归，再迭代公平性/并发性能）。

## 4) 术语与口径（Glossary / Contracts）

- Meeting Room：由矩形拖拽创建的房间类型（不同于 Workspace）。
- Meeting Table：会议室自动摆放的桌子（`assets/meeting_room/Table.glb` 的 wrapper）。
- Meeting State：NPC 处于“参会待命”模式的运行时状态（不等于对话/不等于 desk-bound work）。
- Participant（参会者）：处于 meeting state 且加入 meeting channel 的 NPC。
- Meeting Channel：每个 Meeting Room 对应的文本通道（语义上是 IRC channel；实现上允许有 headless fallback）。
- Host / Human：玩家通过 mic overlay 发送的消息来源（可视为主持人/人类输入源）。

## 5) 用户画像与关键场景（Personas & Scenarios）

- S1（摆位入会）：玩家选中 NPC → 右键点击会议桌周围地面 → NPC 到位停下 → 自动进入 meeting state → 加入 channel 待命。
- S2（群聊广播）：玩家双击 mic → 打开 MeetingRoomChatOverlay → 输入一句话并发送 → 所有参会 NPC 都“听到”并可以选择回复。
- S3（点名必答）：玩家消息包含明确点名（例如 `@Alice` 或 `Alice:`）→ 被点名 NPC 必须回复；未点名 NPC 仍可选择性回复。
- S4（离开会议）：NPC 被再次右键指令移动到远离会议桌的位置（或走出半径阈值）→ 自动退出 meeting state → 从 channel 离开待命。
- S5（房间删除）：会议室被删除 → 参会 NPC 自动退出 meeting state（防止悬挂状态/残留订阅）。

## 6) 需求清单（Requirements with Req IDs）

| Req ID | 需求描述 | 验收口径（可二元判定） | 验证方式（命令/测试/步骤） | 优先级 | 依赖/风险 |
|---|---|---|---|---|---|
| REQ-001 | 定义 meeting state 的进入/退出规则（围绕 meeting table 2m 半径） | NPC 到达 move-to 目标点后：若目标点到 meeting table anchor 距离 ≤ 2.0m，则进入 meeting state；若后续离开 ≥ 2.2m（滞回）则退出 | 自动化测试：模拟 NPC move_target_reached 事件 + 位置判定；验证 NPC 状态字段/分组变化 | P0 | 需要稳定的 table anchor 获取方式 |
| REQ-002 | Meeting Room 提供可定位的“meeting table anchor” | 每个 meeting room node 能提供一个 `Vector3` anchor（桌子中心/桌边中心之一，需在 PRD 里固定口径） | 测试：meeting room 节点树里能找到 anchor 节点或可计算；在 headless 场景不依赖渲染 | P0 | 资产 bounds/缩放会影响 anchor 计算 |
| REQ-003 | 每个 Meeting Room 派生一个稳定的 IRC channel 名称 | 同一 `save_id + meeting_room_id` 推导出的 channel 名称稳定不变、只含安全字符、长度受限 | 单测/脚本：对不同 id 生成并校验格式与稳定性；与 `VrOfficesIrcNames` 风格一致 | P0 | 需要决定命名方案与长度约束 |
| REQ-004 | NPC 进入 meeting state 后加入 meeting channel 待命 | 当 NPC 进入 meeting state 时：MeetingChannel 参与者列表包含该 NPC；退出时移除 | 自动化测试：进入/退出触发 join/part；无重复加入；无泄漏 | P0 | 并发：多个 NPC 同时加入/退出 |
| REQ-005 | mic overlay 的输入作为 “Human/Host” 消息发布到 meeting channel | 从 MeetingRoomChatOverlay 发送一条消息 → meeting channel 广播给所有参会 NPC（含点名元数据） | 集成测试：打开 overlay → 提交消息 → mock OA 收到对每个参会 NPC 的 turn 调用 | P0 | UI 与 channel 的解耦、避免影响 NPC 对话 overlay |
| REQ-006 | 参会 NPC 的“是否回应”策略（含点名必答） | 未点名：允许 0..N 个 NPC 回复；点名：被点名 NPC 必须回复（至少 1 条可见消息/或明确“不回应”的系统消息） | 单测/集成测试：构造消息包含 `@npc_name`；验证目标 NPC 必产生一次 turn/回复 | P0 | 点名规则需清晰，避免误触发 |
| REQ-007 | 点名规则固定且可预测 | 仅支持明确格式：`@DisplayName` / `@npc_id` / `DisplayName:` / `npc_id:`（大小写策略需明确） | 单测：输入样例 → 解析出 expected mentions | P1 | 多语言/空格/标点边界处理 |
| REQ-008 | 复用/扩展既有 IRC/RPC 传输层以承载长回复 | 长回复不会被粗暴硬切导致乱码或语义断裂；IRC 单行限制下可重组（类似 `OAMEDIA1F`） | 单测：编码→分片→重组；集成测试：NPC 生成长回复仍能完整显示 | P1 | 与 `OA1 ` 工具 RPC 前缀冲突风险 |
| REQ-009 | 可观测性：channel 加入/退出/消息事件可追踪 | 每个 meeting room 有可读日志（磁盘或内存快照），包含 join/part 与消息摘要 | 测试：触发 join/消息后日志存在且含关键行 | P2 | 日志体积与隐私控制 |
| REQ-010 | 删除 meeting room 时清理状态 | 删除 meeting room → channel 关闭/清理；参会 NPC 状态回落到非 meeting | 集成测试：删除 room 后 participants 清空、NPC 退出 meeting | P0 | 生命周期管理与引用悬挂 |
| REQ-011 | 会议桌周围显示“呼吸灯圈”提示参会区域 | 每个 meeting room 的桌子周围有一个柔光、呼吸的区域指示；玩家把 NPC 放进圈内即可入会 | 目测 + 自动化：节点树包含 `Decor/MeetingZoneIndicator`；shader 允许 headless 编译 | P1 | 视觉与规则一致性（圈形状 vs 判定） |
| REQ-012 | （可选）Meeting Room 群聊桥接到真实 IRC server 的 channel（含 NPC join/part） | 当 IRC 配置可用且非 headless：meeting room 派生的 channel 在 IRC 上能观察到真实 `JOIN/PART/PRIVMSG`；NPC 入会时 join、离会时 part；人类 mic 消息与 NPC 回复都能被外部观察者看到 | 自动化（离线）：smoke 测试验证 wiring + 模拟 IRC message 使 link ready；手动（在线）：连接到测试 IRC server 验证 JOIN/PART/PRIVMSG | P1 | 多连接开销（每 NPC 1 连接）；测试不能依赖外网；需要设置开关/降级策略 |

## 7) 约束与不接受（Constraints）

- C1：会议室功能必须独立维护（代码放在 `vr_offices/core/meeting_rooms/` 及其子模块；避免与 workspaces/desks “互相污染”）。
- C2：Godot 4.6 strict mode：避免 `var x := null` 触发类型推断问题；必要时显式 nullable 类型或 Variant。
- C3：自动化测试必须可在 headless 环境运行；不能强依赖外部 IRC 网络服务。
- C4：现有 desk IRC 的 `OA1 ` RPC 前缀保留给工具；会议群聊若复用分片协议需避免与工具 RPC 发生歧义。

## 8) 可观测性（可选）

- 建议新增（或复用）meeting-room 级别日志：
  - `meeting_room_id`, `channel_name`, `join(npc_id)`, `part(npc_id)`, `msg(human/npc, len, mentions)`
- 目的：
  - 回归测试证据、排查“NPC 没进会/没收到消息/重复回复”等问题。

## 9) 追溯矩阵（由实施侧维护，避免漂移）

> 本 PRD 的追溯矩阵在 v93 计划阶段补齐（`Req ID -> v93 slice -> tests/commands -> 证据 -> 关键代码路径`）。
