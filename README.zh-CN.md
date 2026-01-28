# OpenAgentic Godot（GDScript）

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
	"gpt-4.1-mini",
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
export OPENAI_BASE_URL=https://api.openai.com/v1
node proxy/server.mjs
```

## 测试（本地）

仓库 `tests/` 里提供了 headless 测试脚本（本地需要 `godot4`）：

```bash
godot4 --headless --script tests/test_sse_parser.gd
godot4 --headless --script tests/test_session_store.gd
godot4 --headless --script tests/test_tool_runner.gd
godot4 --headless --script tests/test_agent_runtime.gd
```

WSL2 + Windows Godot 的便捷脚本：

```bash
scripts/run_godot_tests.sh
```

## Demo（和第一个 NPC 对话）

1. 先启动上面的代理。
2. 运行 Godot 工程。

Demo 可通过环境变量配置：

- `OPENAGENTIC_PROXY_BASE_URL`（默认 `http://127.0.0.1:8787/v1`）
- `OPENAGENTIC_MODEL`（默认 `gpt-4.1-mini`）
- `OPENAGENTIC_SAVE_ID`（默认 `slot1`）
- `OPENAGENTIC_NPC_ID`（默认 `npc_1`）

## 文档 / 计划

- `docs/plan/v1-index.md`
- `docs/plans/2026-01-28-openagentic-godot4-runtime.md`
