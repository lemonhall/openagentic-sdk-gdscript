<!--
  PRD — VR Offices: Multimedia Messages (Dialogue + IRC transport)
  Date: 2026-02-04
-->

# PRD — VR Offices: Multimedia Messages (Dialogue + IRC)

## Vision

让 VR Offices 的 NPC 对话（`DialogueOverlay`）支持“多媒体消息”：图片/音频/视频，且同一套消息表示方式也能在 IRC 纯文本传输中工作。

核心原则：

- **消息中只传递“媒体引用（media ref）”**，不暴露本机绝对路径。
- **链接泄露不等于可访问**：即使媒体引用被转发/泄露，也不能被任意人直接下载。
- **最小媒体类型集**：图片仅 PNG/JPEG；音频仅 MP3/WAV；视频仅 MP4。
- **安全优先**：MIME 探测、大小限制、拒绝可疑内容、缓存隔离与清理。
- **服务独立**：媒体短链/上传服务 **不与** `proxy/` 放在一起（单独目录/进程）。

## Non-goals（本期不做）

- 不做“任意格式媒体”支持（只做最小集合）。
- 不做公开互联网上的匿名分享（必须有鉴权/密钥）。
- 不承诺所有平台都能原生播放 MP4（需要单独验证 Godot/平台编译配置；可先降级为“可下载/可外部打开”）。
- 不把媒体数据直接写入 `events.jsonl`（避免日志爆炸与隐私风险）。

## Background / Current State

- NPC 对话 UI：`vr_offices/ui/DialogueOverlay.gd` 目前仅渲染纯文本气泡（`RichTextLabel`）。
- 对话历史来自每 NPC 的 `events.jsonl`，只重建 `user.message` / `assistant.message`（`vr_offices/core/chat/VrOfficesChatHistory.gd`）。
- IRC 桥接（桌子频道 -> NPC）：`vr_offices/furniture/DeskNpcDeskChannelBridge.gd` 只处理纯文本，并忽略 `OA1 ` 前缀帧（保留给工具 RPC）。
- OpenAgentic runtime 当前“对模型输入”只回放纯文本（`addons/openagentic/runtime/OAReplay.gd`）。

## Requirements（带 Req ID）

### Message format & parsing

- **REQ-001** 定义一个“媒体引用（media ref）”的纯文本编码格式，可在 Dialogue 与 IRC 中传递，并可逆解析为结构化数据（`kind/mime/id/sha256/bytes/filename?/caption?`）。
- **REQ-002** media ref 必须包含足够的校验信息以防混淆与缓存污染：
  - `kind ∈ {image,audio,video}`
  - `mime` 必须在允许列表
  - `bytes`、`sha256`（或等价强校验）用于一致性校验

### Media service（短链/上传/下载）

- **REQ-003** 提供独立的媒体服务（单独目录/进程，**不在** `proxy/`）：
  - 上传：返回 `id + meta`
  - 下载：通过 `id` 获取 bytes
  - 元信息：可选（便于提前渲染占位/校验）
- **REQ-004** 安全性：媒体服务必须在下载与上传侧都做“强校验与限制”：
  - 只接受 PNG/JPEG、MP3/WAV、MP4
  - 基于魔数/文件头做 MIME 探测（不能只信扩展名/客户端声明）
  - 限制单文件大小与总存储占用（阈值在计划中固化）
  - **鉴权必须与消息内容分离**：消息里出现的 `id`（或短链码）本身不足以访问媒体

### Client behavior（VR Offices）

- **REQ-005** `DialogueOverlay` 能渲染 media ref：
  - 图片：显示缩略/自适应宽度
  - 音频：提供基本播放控件（至少 Play/Stop）
  - 视频：至少能“下载到本地缓存并可打开”；若 Godot 原生可播，再提供内嵌播放
- **REQ-006** 客户端缓存：
  - 下载到 `user://openagentic/saves/<save_id>/cache/media/`（或等价 per-save 路径）
  - 基于 `id+sha256` 去重与校验
  - 提供清理策略（按 TTL/LRU/大小上限，至少一个可验证策略）

### Agent workflow（发送/接收）

- **REQ-007** Agent 侧工具与流程：
  - 上传：从 NPC workspace 选择文件（相对路径），上传到媒体服务，得到 media ref（用于发送给人类/IRC）
  - 下载：给定 media ref（或 id），下载到 NPC workspace 的安全路径，返回 **workspace 内相对路径**（不暴露宿主机绝对路径）
- **REQ-008** Agent 与人类发送流程一致（上传 -> 得到 media ref -> 发送文本），并明确失败回退（例如“上传失败：原因”）。

### IRC transport protocol

- **REQ-009** 在 IRC 文本中传递 media ref 的协议约束：
  - 不与 `OA1 ` 冲突（OA1 保留给工具 RPC）
  - 单行可传输；若超过 IRC 单行上限（例如 desk bridge 当前默认约 `360` 字符），必须使用**分片协议**（带 `message_id`、`part/total`）并可重组
  - 禁止对 `OAMEDIA1` 负载进行“硬截断分段发送”（否则 base64url/JSON 会损坏）；必须用显式分片格式
  - Desk bridge 与（未来）IRC UI 能识别并按 media ref 处理

## Proposed Format (v1)

推荐 v1 采用：

- 前缀：`OAMEDIA1 `
- 负载：base64url(JSON)，JSON 最小字段：`{"id":"...","kind":"image","mime":"image/png","bytes":1234,"sha256":"...","name":"...","caption":"..."}`。

理由：

- IRC 与日志中仍然是单行纯文本，可回放、可转发、可解析。
- 通过前缀避免误判普通文本；通过版本号允许未来演进。

## Design Options（对比）

1) **消息中直接放可下载 URL（含签名 token）**  
   - 优点：实现简单，外部 IRC 客户端直接点开
   - 缺点：URL 泄露即意味着可访问（与安全目标冲突）

2) **消息只放 `id`，访问必须携带 bearer（推荐）**  
   - 优点：`id` 泄露不等于可访问；可控；便于缓存校验与策略
   - 缺点：外部客户端需要配置 bearer（或通过受控渠道获取）

3) **把媒体 bytes 直接内嵌在消息中（base64/data URL）**  
   - 优点：无服务依赖
   - 缺点：IRC/日志长度不可控、隐私风险大、性能差（不适用）

## Security Model（必须落到实现与测试）

- 鉴权：媒体服务要求 `Authorization: Bearer <token>`（或等价），该 token 由本地配置/环境变量注入客户端与工具层；**不写入聊天消息**。
- URL 形态：消息中传递的是 `id`（或 `OAMEDIA1 ...`），不是一个可直接在公网访问的裸 URL。
- 下载校验：客户端在落盘前后都校验 `bytes` 与 `sha256`，不匹配则拒绝缓存并报告。
- 路径安全：任何“写入 NPC workspace / cache”的落盘路径都必须走现有 workspace sandbox（禁止 `..`、绝对路径、scheme path）。

## Explicit Limits（v1 约束，必须测试固化）

- `OAMEDIA1` 单条消息最大长度：**512 字符**（超过即拒绝解析；IRC 侧必须走分片协议）。
- 文件大小上限（上传与下载都必须 enforce）：
  - 图片（PNG/JPEG）：≤ **8 MiB**
  - 音频（MP3/WAV）：≤ **20 MiB**
  - 视频（MP4）：≤ **64 MiB**
- 文件名/标题最大长度：**128**（超出截断或拒绝；避免日志污染）

## Configuration (v1)

媒体服务连接信息由本地配置/环境变量提供（不进入消息内容）：

- `OPENAGENTIC_MEDIA_BASE_URL`：例如 `http://127.0.0.1:8788`
- `OPENAGENTIC_MEDIA_BEARER_TOKEN`：用于 upload/download 的 bearer token

约束：

- `OPENAGENTIC_MEDIA_BASE_URL` 必须对 IRC 参与方“接收端”可达（同机 / 局域网 / 公网均可，但必须可连通）；否则接收端无法下载媒体。

## Verification Strategy（E2E 与自动化）

目标：在不依赖人工肉眼看 UI 的情况下，仍然能对“多媒体传输链路”做可重复验证；必要时提供一个“人类发送端”工具用于手工 e2e。

### E2E Flow A — Player → (IRC) → Remote Agent（可自动化）

链路：选择文件 → 上传媒体服务 → 发送 `OAMEDIA1` 到 IRC → 接收侧解析 → 下载到本地/工作区 → 将 **workspace 相对路径** 交给对面 agent。

注：v50 自动化不强依赖“游戏内文件选择 UI”；可以用脚本发送端替代（更可重复）。

自动化验证思路：

- 在测试中启动一个最小 IRC server（本地 TCP）以避免依赖公网 IRC。
- 在测试中启动媒体服务（本地 HTTP）。
- 运行一个“接收侧”的 openagentic/agent runtime（可 headless），收到消息后执行下载并落盘。
- 验证点：
  - 接收侧 workspace/cache 目录存在目标文件
  - `sha256/bytes` 校验通过
  - 返回给 agent 的路径是 workspace 相对路径（不含绝对路径/盘符）

### E2E Flow B — Remote Agent → (IRC) → Player（需要设计；可半自动）

链路：对面 agent 上传媒体 → 发送 `OAMEDIA1` 到 IRC → 玩家游戏接收 → 解析 → 下载到 per-save cache →（可选）展示/播放。

自动化验证思路（不要求“真的播放成功”）：

- 在 VR Offices 测试环境中订阅本地 IRC server 目标频道（需注意：当前 `VrOfficesDeskIrcLink` 在 headless 会跳过网络连接；E2E harness 需要绕过或引入“允许 headless 网络”的测试开关）。
- 用一个脚本客户端发送 `OAMEDIA1` 消息到频道（模拟“对面 agent”）。
- 验证点：
  - 玩家侧 per-save cache 目录出现文件
  - `sha256/bytes` 校验通过
  - 对无效 ref 显示明确占位（可通过 UI 节点/状态断言，不要求截图）

手工验证工具（可选）：

- 提供一个轻量“发送端”小工具（例如 Python/Tk），支持：
  - 选择文件 → 上传 → 自动生成 `OAMEDIA1` → 发送到 IRC
  - 用于你手动对着游戏做 e2e（对面发给玩家/玩家发给对面都能复用）

## Acceptance (Global DoD)

以下每条都必须能被测试/命令二元验证：

1) `DialogueOverlay` 能显示包含 media ref 的消息，并对不合法 ref 给出可见的失败占位（不崩溃）。
2) 媒体服务拒绝所有不在白名单内的 MIME/魔数文件，并记录明确错误码。
3) “消息泄露”不等于可下载：在没有 bearer token 的情况下，下载接口返回 401/403。
4) Agent 工具返回的路径必须是 workspace 相对路径，且无法通过输入绕过 workspace sandbox。
5) 针对每种媒体类型至少 1 个端到端回归测试（可先从图片开始，音频/视频分期）。

## Risks / Open Questions

- Godot 4.6 对 MP4 内嵌播放的支持与跨平台一致性需要尽早验证；若不可行，视频先做“可下载/外部打开”的降级方案。
- 如果未来需要“让模型真正理解媒体内容”，可能需要：
  - 在工具层把媒体转成可喂给模型的内容（例如 base64 + Responses 多模态输入），或
  - 提供 OCR/ASR/视频关键帧摘要等预处理（成本与依赖较高）。
