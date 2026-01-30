---
name: agent-md-101
description: Use when starting a new repo or onboarding an AI agent and you need to create or overhaul an AGENTS.md so work stays safe, testable, and consistent across environments (e.g., Godot + SDK + demo apps), especially when the project has strict tooling, sandboxes, or multiple “products” in one codebase.
---

# 101 项目规约初始化技能：写出合格的 `AGENTS.md`

## Overview

`AGENTS.md` 的作用是：把“项目的现实规则”写成**可执行、可验证、可避免事故**的工程规约，让 AI/新人在不熟悉代码库时也能安全推进。

核心原则：

1) **先让人知道“这是个什么系统”**（架构与数据流）
2) **再让人知道“哪些事绝对不能做”**（Negative Knowledge）
3) **最后让人知道“怎么验证自己没把项目弄坏”**（测试策略与命令）

## When To Use

- 新仓库刚建立，缺少工程规约/AI 开发规约
- 老项目 `AGENTS.md` 只写了“怎么跑”，但没有架构与禁忌，导致反复踩坑
- 一个 repo 里同时包含 SDK + 应用（或多 demo），容易把验证策略搞混
- 跨平台/跨边界执行很痛（WSL/Windows exe、CI、沙盒路径等）

## Required Sections（最低合格线）

### 1) Architecture Overview（架构概览）

写清楚 3 件事：

- **系统拆分**：这个 repo 里有哪些“产品/子系统”（例如 SDK / 主应用 / demo）
- **关键路径**：每个子系统的入口文件、关键模块、核心数据结构的文件路径
- **数据流向**：从 UI/调用方 → 核心服务 → 外部依赖 → 回写/持久化 的路径（最好画一个 10 行以内的 ASCII 图）

必须包含：

- 配置入口（环境变量/配置文件/Autoload/启动参数）
- 持久化目录约定（尤其是 `user://` / `~/.config` / `AppData` 这种）

### 2) Code Conventions (Negative Knowledge)（“千万别这样做”）

写“事故预防清单”，而不是“编码风格建议”。

每条规则都用这个格式：

- **禁止事项**：不要做什么（明确到行为/文件/模块）
- **为什么**：会造成什么后果（安全/数据丢失/测试挂死/接口破坏）
- **替代方案**：该怎么做（具体命令/步骤/脚本）
- **验证方式**：怎么确认你做对了（测试命令/检查脚本）

常见必写项：

- “不要把某个文件写回巨型 god file”（并给出模块化落点）
- “不要靠手测回归”
- “不要提交 secrets”
- “不要绕过 sandbox / workspace 约束”
- “严格模式/警告当错误：避免类型推断/遮蔽变量名”
- “不要动某个 demo/目录（除非明确需求）”

### 3) Testing Strategy（测试策略）

按“产品/模块”分组给出**最短可用命令**：

- **全量测试**（一条命令）
- **单个测试/单模块测试**（一条命令）
- **常见故障排查**（例如：卡死/超时/资源泄漏/verbose）

必须写清楚：

- 在不同环境下怎么跑（Windows / WSL / Linux）
- 避免 hung tests 的策略（每用例 timeout）
- 哪些测试属于 SDK，哪些属于应用层（避免只跑 demo 测试误判）

## Recommended Sections（强烈建议）

- **Repo Safety / Permissions**：哪些操作会触发跨边界审批、怎么最小化审批（例如优先用 Linux 二进制而不是 WSL 调 Windows exe）
- **Runtime Config**：关键 env vars（例如 `OPENAI_API_KEY`、`*_BASE_URL`、`*_MODEL`）
- **Release / Export Notes**：如果要 export（Godot/移动/Web），哪些能力受限、需要替代

## Template（可复制）

```md
# Agent Notes (<Project Name>)

## 1) Architecture Overview
### Areas
- SDK:
  - entry: `path/to/entry`
  - core: `path/to/core`
- App:
  - main: `path/to/main`
  - modules: `path/to/modules`
- Demos:
  - `path/to/demo`

### Data Flow
<10 lines ascii diagram>

### Persistence
- root: `...`
- saves: `...`

## 2) Code Conventions (Negative Knowledge)
- Do not ...
  - Why:
  - Do instead:
  - Verify:

## 3) Testing Strategy
### Full
`<command>`
### SDK
`<command>`
### App
`<command>`
### Debugging
`<command>`
```

## Red Flags（看到就停）

- “先把功能写了，测试后面再补”
- “手动点点看没问题”
- “顺手把 demo 也改一下”
- “这次不需要写进 AGENTS.md”
- “反正我知道路径/命令，写不写都一样”

