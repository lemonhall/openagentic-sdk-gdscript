# OpenAgentic Godot（GDScript）

![截图](screenshot.png)

面向 **Godot 4 运行时** 的 Agent 插件：把 `openagentic-sdk-ts` 的核心 tool-loop 移植到 GDScript，方便在游戏里用 Agent 驱动 Actor/NPC 行为。

- 事件溯源：按存档 + NPC 维度持久化 **连续会话**（JSONL）
- 流式输出：通过 **OpenAI Responses 兼容的 SSE**（走你自己的代理）产生 `assistant.delta`
- 工具调用闭环：工具注册表 → 权限门禁 → 工具执行器（tool runner）
- “shadow workspace”：所有 AI 相关文件都落在 `user://` 的存档目录里（不做 import/commit 工作流）

## 状态

v1 早期最小闭环已实现，API 可能会频繁调整。

## 安装

把 `addons/openagentic/` 复制到你的 Godot 项目，然后添加 Autoload 单例：

- 名称：`OpenAgentic`
- 脚本：`res://addons/openagentic/OpenAgentic.gd`

## 落盘结构（按存档隔离）

所有持久化都限定在：

`user://openagentic/saves/<save_id>/`

每个 NPC 一条“持续一生”的会话（不分 session_id）：

- `.../npcs/<npc_id>/session/events.jsonl`
- `.../npcs/<npc_id>/session/meta.json`

可选“记忆文件”（会注入到 prompt 的 system 前言里）：

- `.../shared/world_summary.txt`（世界/全局摘要）
- `.../npcs/<npc_id>/memory/summary.txt`（NPC 摘要）

## 快速开始（运行时）

```gdscript
OpenAgentic.set_save_id("slot1")

# 指向你自己的代理（兼容 OpenAI Responses API，支持 SSE 流式）。
OpenAgentic.configure_proxy_openai_responses(
	"https://your-proxy.example/v1",
	"gpt-5.2",
	"authorization",
	"<token>",
	true
)

# 工具权限策略（v1：用回调允许/拒绝）。
OpenAgentic.set_approver(func(_q: Dictionary, _ctx: Dictionary) -> bool:
	return true
)

# 注册允许模型调用的工具（用于驱动 NPC/Actor 行为）。
OpenAgentic.register_tool(OATool.new(
	"echo",
	"回显输入",
	func(input: Dictionary, _ctx: Dictionary):
		return input
))

await OpenAgentic.run_npc_turn("npc_blacksmith_001", "你好", func(ev: Dictionary) -> void:
	# 这里会收到 assistant.delta/tool.use/tool.result/assistant.message/result 等事件
	print(ev)
)
```

## 代理要求（SSE）

客户端不保存长期 API Key；通过你的代理调用：

- `POST /v1/responses`（请求体含 `stream: true`）
- 响应为 SSE：`data: ...` 帧 + `[DONE]` 结束

本仓库内置了一个无依赖的 Node.js 代理（`proxy/`）：

```bash
export OPENAI_API_KEY=...
export OPENAI_BASE_URL=https://api.openai.com/v1  # 可选
node proxy/server.mjs
```

## 测试（本地）

仓库 `tests/` 里提供了 headless 测试脚本（本地需要 `godot4`）：

```bash
godot4 --headless --script tests/addons/openagentic/test_sse_parser.gd
godot4 --headless --script tests/addons/openagentic/test_session_store.gd
godot4 --headless --script tests/addons/openagentic/test_tool_runner.gd
godot4 --headless --script tests/addons/openagentic/test_agent_runtime.gd
```

WSL2 + Windows Godot 的便捷脚本：

```bash
scripts/run_godot_tests.sh
scripts/run_godot_tests.sh --suite openagentic
scripts/run_godot_tests.sh --suite vr_offices
```

## Demo（和第一个 NPC 对话）

1. 先启动上面的代理。
2. 运行 Godot 工程。
   - 默认主场景是 3D 的 VR Offices demo：`res://vr_offices/VrOffices.tscn`
   - RPG 风格 demo 仍保留在：`res://demo_rpg/World.tscn`
   - 旧的“聊天 UI” demo 仍保留在：`res://demo/Main.tscn`

## VR Offices（3D demo）

一个单独的 3D “办公室模拟”原型在 `vr_offices/` 下。

1. 解包素材（Kenney Mini Characters 1）：

```bash
scripts/setup_kenney_mini_characters.sh
```

2. 打开并运行：`res://vr_offices/VrOffices.tscn`

操作：

- 镜头环绕：按住鼠标右键拖动
- 缩放：滚轮
- 添加/移除 NPC：左上角 UI（点击 NPC 选中）

## 美术资源

RPG demo 使用 Kenney 的 CC0 资源。如果你的仓库里还没有素材，可以从本地 zip 一键解包导入：

```bash
scripts/import_kenney_roguelike_rpg_pack.sh
scripts/import_kenney_roguelike_characters.sh
```

见 `assets/CREDITS.md`。

## 碰撞 Mask（自动初稿）

对于“一张背景图”的地图，可以用一张 PNG mask 自动生成碰撞（mask 不透明区域 = 障碍）：

- 生成脚本：`python3 scripts/generate_collision_mask.py <background.png> --out <mask.png>`
- 运行时生成碰撞：`demo_rpg/collision/OACollisionFromMask.gd`

详细机制：`docs/collision_masks/README.md`

Demo 可通过环境变量配置：

- `OPENAGENTIC_PROXY_BASE_URL`（默认 `http://127.0.0.1:8787/v1`）
- `OPENAGENTIC_MODEL`（默认 `gpt-5.2`）
- `OPENAGENTIC_SAVE_ID`（默认 `slot1`）
- `OPENAGENTIC_NPC_ID`（默认 `npc_1`）

## 文档 / 计划

- `docs/plan/v1-index.md`
- `docs/plan/v2-index.md`
- `docs/plan/v2-rpg-demo.md`
- `docs/plan/v3-index.md`
- `docs/plan/v3-vr-offices.md`
- `docs/plans/2026-01-28-openagentic-godot4-runtime.md`
