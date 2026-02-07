# 一、产品需求文档（PRD）

---

## 多Agent共享文件系统

**文档版本**：1.0
**日期**：2026-02-07
**作者**：系统架构组
**状态**：评审中

---

### 1. 背景与动机

在多Agent协作系统中，多个AI Agent需要在同一个项目空间内读写文件。当前常见做法是让所有Agent共享一个扁平目录，依赖"口头约定"避免互相覆盖。这在Agent数量增加、任务并行度提高时会产生严重问题：

- **静默覆盖**：Agent A写入的文件被Agent B无意覆盖，A的工作成果丢失，且没有任何提示
- **读写时序混乱**：Agent A正在写入一个文件，Agent B同时读取到半成品
- **职责边界模糊**：无法从文件系统层面区分"谁负责什么"，全靠提示词约束，不可靠
- **无法追溯**：文件被改坏后无法回退，不知道是谁在什么时候改的

这些问题在人类团队中通过Git、Google Docs、Notion等工具解决。我们需要为Agent世界构建等价的基础设施。

---

### 2. 产品目标

构建一个**运行在Godot引擎内的多Agent共享文件系统**，使得：

1. 每个Agent拥有明确的文件所有权边界，从结构上消除大部分冲突
2. 需要协作的场景有清晰的冲突检测与解决机制
3. 需要实时并发编辑的场景能自动无冲突合并
4. Agent通过标准化的工具接口（tool calling）操作文件，无需理解底层机制
5. 所有文件操作可追溯、可回退

---

### 3. 用户画像

| 角色 | 说明 |
|---|---|
| **AI Agent** | 系统的直接使用者。通过LLM的tool calling机制调用文件操作。不同Agent承担不同职责（调研、分析、写作、编码等） |
| **系统编排器（Orchestrator）** | 管理Agent生命周期的上层系统。负责初始化共享文件系统、分配Agent ID、注入工具定义 |
| **人类监督者** | 可能通过UI查看文件系统状态、审阅Agent产出、手动干预冲突 |

---

### 4. 核心概念

#### 4.1 三区模型

整个文件系统划分为三个区域，对应三种协作模式：

**专属区（Private Workspace）**
- 类比：每个人自己的桌面/草稿本
- 每个Agent有一个独立目录，只有自己能写入，其他人只读
- 适用于：草稿、中间结果、个人笔记、工作产出

**交接区（Handoff Zone）**
- 类比：办公室里的"收件箱"
- Agent A可以把文件"正式交付"给Agent B，附带交接说明
- 单向传递，有明确的发送方和接收方
- 适用于：任务产出物的正式传递、上下游交接

**协作区（Collaborative Zone）**
- 类比：共享文档 / Git仓库
- 多个Agent可以读写同一个文件
- 提供两种并发控制策略：
  - **版本控制模式**：适合轮流编辑，通过版本号检测冲突
  - **实时协作模式（CRDT）**：适合同时编辑，数学保证无冲突自动合并

#### 4.2 选择策略

```
这个文件会被多个Agent写入吗？
├── 否 → 专属区
└── 是 → 需要同时编辑吗？
    ├── 否（轮流编辑）→ 协作区·版本控制模式
    └── 是（同时编辑）→ 协作区·实时协作模式（CRDT）
```

Agent不需要自己做这个判断。编排器在任务分配时指定使用哪种模式，或者在系统提示词中给出明确指引。

---

### 5. 功能需求

#### FR-1：专属工作区

| 编号 | 需求 | 优先级 |
|---|---|---|
| FR-1.1 | 系统初始化时为每个Agent创建独立目录 `agents/{agent_id}/` | P0 |
| FR-1.2 | Agent可以在自己的目录下创建、读取、覆盖、删除文件 | P0 |
| FR-1.3 | Agent可以读取其他Agent目录下的文件（只读） | P0 |
| FR-1.4 | Agent尝试写入其他Agent目录时，系统拒绝并返回明确错误 | P0 |
| FR-1.5 | Agent可以列出自己或其他Agent目录下的文件列表 | P0 |

#### FR-2：交接区

| 编号 | 需求 | 优先级 |
|---|---|---|
| FR-2.1 | Agent可以将文件交接给指定的另一个Agent，附带文字说明 | P0 |
| FR-2.2 | 交接文件存储在 `handoff/{from}_to_{to}/` 目录下 | P0 |
| FR-2.3 | 交接时自动生成元数据文件，记录发送方、时间戳、说明 | P0 |
| FR-2.4 | 接收方Agent可以查询"有哪些文件交接给了我" | P0 |
| FR-2.5 | 接收方Agent可以读取交接给自己的文件内容 | P0 |

#### FR-3：协作区·版本控制模式

| 编号 | 需求 | 优先级 |
|---|---|---|
| FR-3.1 | Agent可以创建协作文件，系统自动分配版本号1 | P0 |
| FR-3.2 | Agent读取文件时，返回内容和当前版本号 | P0 |
| FR-3.3 | Agent写入文件时必须提供期望版本号（基于哪个版本修改的） | P0 |
| FR-3.4 | 如果期望版本号与当前版本号不匹配，拒绝写入并返回冲突信息 | P0 |
| FR-3.5 | 冲突信息包含：当前版本号、当前内容、当前作者、冲突建议 | P0 |
| FR-3.6 | 每次成功写入自动递增版本号，记录作者、时间戳、提交说明 | P0 |
| FR-3.7 | 可以查看文件的完整修改历史 | P1 |
| FR-3.8 | 可以回滚到历史版本（创建一个新版本，内容等于旧版本） | P1 |
| FR-3.9 | 每个版本计算内容校验和，用于完整性验证 | P2 |

#### FR-4：协作区·实时协作模式（CRDT）

| 编号 | 需求 | 优先级 |
|---|---|---|
| FR-4.1 | 可以创建实时协作文档，定义字段名和字段类型 | P0 |
| FR-4.2 | 支持的字段类型：单值（LWW）、文本（RGA）、集合（ORSet）、键值对（LWWMap）、计数器（PNCounter） | P0 |
| FR-4.3 | 多个Agent对同一文档的并发操作能自动合并，不产生冲突 | P0 |
| FR-4.4 | 文本字段支持按位置插入、按范围删除、替换、获取全文 | P0 |
| FR-4.5 | 集合字段支持添加、删除、列出、查询是否包含 | P0 |
| FR-4.6 | 计数器字段支持递增、递减、获取当前值 | P0 |
| FR-4.7 | 可以获取整个文档的快照（所有字段的当前值） | P0 |
| FR-4.8 | 文档状态自动持久化到磁盘，重启后可恢复 | P1 |
| FR-4.9 | 支持从远程Agent接收文档状态并合并（为未来网络同步预留） | P2 |

#### FR-5：工具接口

| 编号 | 需求 | 优先级 |
|---|---|---|
| FR-5.1 | 所有文件操作封装为标准化的tool定义，可直接传给LLM API | P0 |
| FR-5.2 | 提供统一的调用分发器，根据tool名称路由到对应实现 | P0 |
| FR-5.3 | 所有工具返回结构化的Dictionary结果，包含success字段 | P0 |
| FR-5.4 | 冲突场景的返回结果包含人类可读的建议文本，帮助Agent理解如何处理 | P0 |
| FR-5.5 | 提供系统提示词模板，向Agent解释文件系统的使用方式和选择策略 | P1 |

---

### 6. 非功能需求

| 编号 | 需求 | 说明 |
|---|---|---|
| NFR-1 | **线程安全** | 多个Agent可能在不同线程运行，关键路径需要互斥锁保护 |
| NFR-2 | **纯本地运行** | 第一版不依赖网络，所有数据存储在本地磁盘 |
| NFR-3 | **Godot原生** | 使用GDScript实现，仅依赖Godot内置API（FileAccess、DirAccess、Mutex等） |
| NFR-4 | **可序列化** | 所有CRDT状态可序列化为JSON，支持持久化和未来的网络传输 |
| NFR-5 | **幂等性** | CRDT合并操作是幂等的——重复合并同一状态不改变结果 |
| NFR-6 | **最终一致性** | 所有Agent最终看到相同的CRDT文档状态，无论操作到达顺序 |
| NFR-7 | **性能** | 单次文件操作延迟 < 50ms（本地磁盘IO为主） |

---

### 7. 不做什么（Scope Out）

- **不做**实时网络同步（第一版是单机多Agent，网络同步作为未来扩展）
- **不做**文件级别的细粒度权限控制（如"Agent A可以读B的某个文件但不能读另一个"）
- **不做**大文件/二进制文件支持（聚焦文本文件）
- **不做**文件系统的图形化管理界面（第一版通过代码和日志监控）
- **不做**自动冲突合并（版本控制模式下冲突由Agent自行合并，系统只负责检测）

---

### 8. 磁盘目录结构

```
{workspace_root}/
├── agents/                          # 专属区
│   ├── researcher/
│   │   ├── raw_data.md
│   │   └── notes.txt
│   ├── analyst/
│   │   └── analysis.md
│   └── writer/
│       └── draft.md
│
├── handoff/                         # 交接区
│   ├── researcher_to_analyst/
│   │   ├── raw_data.md
│   │   └── raw_data.md.meta.json
│   └── analyst_to_writer/
│       ├── final_analysis.md
│       └── final_analysis.md.meta.json
│
├── collaborative/                   # 协作区·版本控制
│   ├── .versions/
│   │   └── project_plan.md/
│   │       ├── v1.txt
│   │       ├── v2.txt
│   │       └── history.json
│   └── current/
│       └── project_plan.md
│
└── realtime/                        # 协作区·实时协作
    └── .crdt_state/
        └── task_board.crdt.json
```

---

### 9. 成功指标

| 指标 | 目标 |
|---|---|
| 并发写入零数据丢失 | 任何场景下Agent的写入不会被静默覆盖 |
| 冲突可检测率 | 版本控制模式下100%的并发冲突被检测到 |
| CRDT合并正确率 | 任意操作顺序下合并结果一致（可通过属性测试验证） |
| Agent工具调用成功率 | 正确使用工具时成功率 > 99% |
| 冲突恢复率 | Agent收到冲突提示后，能在1-2轮重试内成功提交 |

---

### 10. 里程碑

| 阶段 | 内容 | 预计周期 |
|---|---|---|
| M1 | 专属区 + 交接区 + 工具接口 | 1周 |
| M2 | 协作区·版本控制模式 | 1周 |
| M3 | 协作区·CRDT实时协作 | 2周 |
| M4 | 集成测试 + LLM对接验证 | 1周 |
| M5（未来） | 网络同步、多机部署 | 待定 |

---

### 11. 开放问题

| 问题 | 当前倾向 | 待讨论 |
|---|---|---|
| CRDT文档的字段schema能否动态修改？ | 第一版只支持创建时定义，不支持后续增删字段 | 是否需要schema迁移机制 |
| 版本历史保留多久？ | 全量保留，不自动清理 | 是否需要压缩/归档策略 |
| Agent是否能删除协作区文件？ | 第一版不支持删除，只支持覆盖 | 删除的语义和权限如何定义 |
| 交接文件是否有过期机制？ | 第一版不过期 | 长期运行时交接区会膨胀 |

---
---

# 二、测试用例

---

## 模块A：专属工作区

### A-1：正常写入自己的工作区

**前置条件**：系统已初始化，包含Agent "alice"。

**操作步骤**：
1. Alice调用 `save_to_my_workspace`，文件名为 `notes.md`，内容为 `Hello World`。

**预期结果**：
- 返回 success = true。
- 磁盘上 `agents/alice/notes.md` 文件存在，内容为 `Hello World`。

---

### A-2：覆盖自己工作区的已有文件

**前置条件**：Alice的工作区已有文件 `notes.md`，内容为 `旧内容`。

**操作步骤**：
1. Alice调用 `save_to_my_workspace`，文件名为 `notes.md`，内容为 `新内容`。

**预期结果**：
- 返回 success = true。
- 文件内容变为 `新内容`。

---

### A-3：读取自己工作区的文件

**前置条件**：Alice的工作区有文件 `notes.md`，内容为 `我的笔记`。

**操作步骤**：
1. Alice调用 `read_from_workspace`，agent_id 为 `alice`，文件名为 `notes.md`。

**预期结果**：
- 返回 success = true，content 为 `我的笔记`。

---

### A-4：读取其他Agent工作区的文件（只读访问）

**前置条件**：Bob的工作区有文件 `report.md`，内容为 `Bob的报告`。

**操作步骤**：
1. Alice调用 `read_from_workspace`，agent_id 为 `bob`，文件名为 `report.md`。

**预期结果**：
- 返回 success = true，content 为 `Bob的报告`。

---

### A-5：尝试写入其他Agent的工作区（应被拒绝）

**前置条件**：系统包含Agent "alice" 和 "bob"。

**操作步骤**：
1. Alice调用底层的 `write_own`，但传入的 agent_id 为 `bob`（或通过任何方式尝试写入 `agents/bob/` 目录）。

**预期结果**：
- 返回错误（ERR_FILE_NO_PERMISSION 或类似错误码）。
- Bob的工作区不受影响。

---

### A-6：读取不存在的文件

**前置条件**：Alice的工作区为空。

**操作步骤**：
1. Alice调用 `read_from_workspace`，agent_id 为 `alice`，文件名为 `nonexistent.md`。

**预期结果**：
- 返回 success = false，包含文件不存在的错误信息。

---

### A-7：列出工作区文件

**前置条件**：Alice的工作区有 `a.md`、`b.txt`、`c.json` 三个文件。

**操作步骤**：
1. Alice调用 `list_workspace_files`，agent_id 为 `alice`。

**预期结果**：
- 返回 success = true，files 数组包含 `a.md`、`b.txt`、`c.json`（顺序不限）。

---

### A-8：列出空工作区

**前置条件**：Bob的工作区为空。

**操作步骤**：
1. Alice调用 `list_workspace_files`，agent_id 为 `bob`。

**预期结果**：
- 返回 success = true，files 为空数组。

---

## 模块B：交接区

### B-1：正常交接文件

**前置条件**：系统包含Agent "alice" 和 "bob"。

**操作步骤**：
1. Alice调用 `handoff_file`，to_agent 为 `bob`，文件名为 `data.csv`，内容为 `1,2,3`，message 为 `请分析这份数据`。

**预期结果**：
- 返回 success = true。
- 磁盘上 `handoff/alice_to_bob/data.csv` 存在，内容为 `1,2,3`。
- 磁盘上 `handoff/alice_to_bob/data.csv.meta.json` 存在，包含 from、to、timestamp、message 字段。

---

### B-2：接收方检查交接

**前置条件**：Alice已向Bob交接了 `data.csv`（附带说明 `请分析`），Charlie也向Bob交接了 `config.json`（附带说明 `新配置`）。

**操作步骤**：
1. Bob调用 `check_my_handoffs`。

**预期结果**：
- 返回 success = true，count = 2。
- handoffs 数组包含两条记录，分别来自 alice 和 charlie，包含文件名和说明。

---

### B-3：没有交接时检查

**前置条件**：没有任何Agent向Bob交接过文件。

**操作步骤**：
1. Bob调用 `check_my_handoffs`。

**预期结果**：
- 返回 success = true，count = 0，handoffs 为空数组。

---

### B-4：读取交接文件内容

**前置条件**：Alice已向Bob交接了 `data.csv`，内容为 `1,2,3`。

**操作步骤**：
1. Bob调用 `read_handoff`，from_agent 为 `alice`，文件名为 `data.csv`。

**预期结果**：
- 返回 success = true，content 为 `1,2,3`，from 为 `alice`。

---

### B-5：同一对Agent多次交接同名文件（后者覆盖前者）

**前置条件**：Alice已向Bob交接了 `data.csv`，内容为 `旧数据`。

**操作步骤**：
1. Alice再次调用 `handoff_file`，to_agent 为 `bob`，文件名为 `data.csv`，内容为 `新数据`，message 为 `更新了`。

**预期结果**：
- 返回 success = true。
- Bob读取该文件时，内容为 `新数据`。
- 元数据文件的 message 为 `更新了`。

---

## 模块C：协作区·版本控制模式

### C-1：创建新的协作文件

**前置条件**：协作区为空。

**操作步骤**：
1. Alice调用 `collab_write`，filepath 为 `plan.md`，content 为 `初稿`，message 为 `创建文档`，expected_version 为 -1。

**预期结果**：
- 返回 success = true，version = 1。
- `collaborative/current/plan.md` 内容为 `初稿`。
- 版本历史中有一条记录：v1，作者 alice，说明 `创建文档`。

---

### C-2：正常的顺序编辑

**前置条件**：`plan.md` 当前为 v1，内容为 `初稿`。

**操作步骤**：
1. Bob调用 `collab_read`，filepath 为 `plan.md`。确认返回 version = 1。
2. Bob调用 `collab_write`，filepath 为 `plan.md`，content 为 `修改稿`，message 为 `补充内容`，expected_version = 1。

**预期结果**：
- 步骤1返回 version = 1，content = `初稿`。
- 步骤2返回 success = true，version = 2。
- 当前内容为 `修改稿`。

---

### C-3：并发冲突检测

**前置条件**：`plan.md` 当前为 v1，内容为 `初稿`。

**操作步骤**：
1. Alice调用 `collab_read`，得到 version = 1。
2. Bob调用 `collab_read`，也得到 version = 1。
3. Alice调用 `collab_write`，expected_version = 1，content 为 `Alice的修改`。成功，变为 v2。
4. Bob调用 `collab_write`，expected_version = 1（过期了！），content 为 `Bob的修改`。

**预期结果**：
- 步骤3成功，version = 2。
- 步骤4失败，返回 is_conflict = true。
- 冲突信息包含：current_version = 2，current_content = `Alice的修改`，current_author = `alice`，your_content = `Bob的修改`。
- 冲突信息包含建议文本，指导Bob读取最新版本并合并。
- 文件内容仍为 `Alice的修改`（Bob的写入被拒绝，没有数据丢失）。

---

### C-4：冲突后正确恢复

**前置条件**：接C-3，Bob的写入被拒绝。

**操作步骤**：
1. Bob调用 `collab_read`，得到 version = 2，content = `Alice的修改`。
2. Bob将自己的修改与Alice的修改合并，得到 `合并后的内容`。
3. Bob调用 `collab_write`，expected_version = 2，content 为 `合并后的内容`，message 为 `合并Alice和Bob的修改`。

**预期结果**：
- 返回 success = true，version = 3。
- 当前内容为 `合并后的内容`。

---

### C-5：查看修改历史

**前置条件**：`plan.md` 经过三次修改，当前为 v3。

**操作步骤**：
1. 任意Agent调用 `collab_history`，filepath 为 `plan.md`。

**预期结果**：
- 返回 success = true。
- history 数组包含3条记录，每条包含 version、author、message、timestamp。
- 按版本号升序排列。

---

### C-6：回滚到历史版本

**前置条件**：`plan.md` 当前为 v3，v1的内容为 `初稿`。

**操作步骤**：
1. Alice调用 `collab_rollback`，filepath 为 `plan.md`，to_version = 1。

**预期结果**：
- 返回 success = true，new_version = 4（回滚是创建新版本，不是删除历史）。
- 当前内容为 `初稿`（与v1相同）。
- 历史中有4条记录，v4的说明类似 `回滚到版本1`。

---

### C-7：读取不存在的协作文件

**前置条件**：协作区没有 `nonexistent.md`。

**操作步骤**：
1. Alice调用 `collab_read`，filepath 为 `nonexistent.md`。

**预期结果**：
- 返回 success = false（或返回 null），表示文件不存在。

---

### C-8：expected_version 为 -1 但文件已存在

**前置条件**：`plan.md` 已存在，当前为 v2。

**操作步骤**：
1. Alice调用 `collab_write`，filepath 为 `plan.md`，expected_version = -1（表示"我以为这是新建"）。

**预期结果**：
- 应当成功写入（expected_version = -1 视为"不检查版本"），创建 v3。
- 或者：如果设计上 -1 严格表示"仅新建"，则应返回冲突。
- （此处需确认产品决策。当前实现中 -1 表示不检查，直接写入。）

---

## 模块D：实时协作·LWW寄存器

### D-1：基本的设置和读取

**前置条件**：创建了实时文档 `doc1`，包含 lww_register 字段 `title`。

**操作步骤**：
1. Alice调用 `realtime_set_field`，doc_id 为 `doc1`，field_name 为 `title`，value 为 `第一版标题`。
2. Alice调用 `realtime_get_field`，doc_id 为 `doc1`，field_name 为 `title`。

**预期结果**：
- 步骤2返回 value = `第一版标题`。

---

### D-2：并发写入同一LWW字段（最后写入者胜出）

**前置条件**：文档 `doc1` 有 lww_register 字段 `title`。

**操作步骤**：
1. Alice在时刻T1设置 `title` 为 `Alice的标题`。
2. Bob在时刻T2（T2 > T1）设置 `title` 为 `Bob的标题`。
3. 读取 `title`。

**预期结果**：
- 值为 `Bob的标题`（时间戳更大的胜出）。

---

### D-3：LWW时间戳相同时按Agent ID排序

**前置条件**：文档 `doc1` 有 lww_register 字段 `status`。

**操作步骤**：
1. 构造两个LWWRegister，时间戳完全相同，agent_id 分别为 `alice` 和 `bob`。
2. 合并两个寄存器。

**预期结果**：
- 结果确定且一致。无论合并顺序如何（先合并alice再bob，或反过来），结果相同。
- 具体胜出者取决于agent_id的字典序比较规则（当前实现：ID更大的

好，从D-3的预期结果接着继续，把所有剩余测试用例补完。

---

### D-3（续）：LWW时间戳相同时按Agent ID排序

**预期结果**：
- 结果确定且一致。无论合并顺序如何（先合并alice再bob，或反过来），结果相同。
- 具体胜出者取决于agent_id的字典序比较规则（当前实现：ID字典序更大的胜出，即 `bob` > `alice`，所以bob的值胜出）。
- 关键验证点：**交换律**——`merge(A, B)` 与 `merge(B, A)` 结果完全相同。

---

## 模块E：实时协作·RGA文本

### E-1：空文档插入文本

**前置条件**：文档 `doc1` 有 rga 字段 `body`，初始为空。

**操作步骤**：
1. Alice调用 `realtime_edit_text`，operation 为 `insert`，args 为 `{position: 0, text: "Hello"}`。
2. 读取 `body`。

**预期结果**：
- 文本为 `Hello`，长度为 5。

---

### E-2：在已有文本中间插入

**前置条件**：`body` 当前内容为 `Hello`。

**操作步骤**：
1. Alice调用 `realtime_edit_text`，operation 为 `insert`，args 为 `{position: 5, text: " World"}`。
2. 读取 `body`。

**预期结果**：
- 文本为 `Hello World`，长度为 11。

---

### E-3：删除文本范围

**前置条件**：`body` 当前内容为 `Hello World`。

**操作步骤**：
1. Alice调用 `realtime_edit_text`，operation 为 `delete`，args 为 `{from: 5, to: 11}`。
2. 读取 `body`。

**预期结果**：
- 文本为 `Hello`，长度为 5。
- 返回 deleted_count = 6。

---

### E-4：替换文本

**前置条件**：`body` 当前内容为 `Hello`。

**操作步骤**：
1. Alice调用 `realtime_edit_text`，operation 为 `replace`，args 为 `{from: 0, to: 5, text: "Hi"}`。
2. 读取 `body`。

**预期结果**：
- 文本为 `Hi`，长度为 2。

---

### E-5：两个Agent同时在不同位置插入（并发不冲突）

**前置条件**：`body` 当前内容为 `AC`。

**操作步骤**：
1. Alice在位置1插入 `B`（意图：在A和C之间插入B）。
2. Bob在位置2插入 `D`（意图：在C之后追加D）。
3. 读取 `body`。

**预期结果**：
- 文本包含所有四个字符 `A`、`B`、`C`、`D`。
- Alice的 `B` 出现在 `A` 和 `C` 之间。
- Bob的 `D` 出现在 `C` 之后。
- 最终文本为 `ABCD`。
- 关键验证点：无论操作到达顺序如何，结果相同。

---

### E-6：两个Agent同时在相同位置插入（并发自动排序）

**前置条件**：`body` 当前内容为 `AC`。

**操作步骤**：
1. Alice在位置1插入 `X`。
2. Bob在位置1插入 `Y`。
3. 读取 `body`。

**预期结果**：
- 文本包含 `A`、`X`、`Y`、`C` 四个字符。
- `X` 和 `Y` 都在 `A` 和 `C` 之间。
- `X` 和 `Y` 的相对顺序是确定的（由agent_id或时间戳决定），无论操作到达顺序如何，结果一致。
- 关键验证点：**收敛性**——两个Agent各自看到的最终文本完全相同。

---

### E-7：插入位置超出范围时的处理

**前置条件**：`body` 当前内容为 `Hi`（长度2）。

**操作步骤**：
1. Alice调用 `realtime_edit_text`，operation 为 `insert`，args 为 `{position: 999, text: "!"}`。
2. 读取 `body`。

**预期结果**：
- 不崩溃。
- `!` 被追加到末尾，文本为 `Hi!`。
- （position被clamp到有效范围）

---

## 模块F：实时协作·ORSet集合

### F-1：添加元素

**前置条件**：文档 `doc1` 有 or_set 字段 `tags`，初始为空。

**操作步骤**：
1. Alice添加元素 `important`。
2. Alice添加元素 `urgent`。
3. 列出所有元素。

**预期结果**：
- 集合包含 `important` 和 `urgent`，count = 2。

---

### F-2：删除元素

**前置条件**：`tags` 包含 `important` 和 `urgent`。

**操作步骤**：
1. Alice删除 `important`。
2. 列出所有元素。

**预期结果**：
- 集合只包含 `urgent`，count = 1。

---

### F-3：添加重复元素

**前置条件**：`tags` 已包含 `urgent`。

**操作步骤**：
1. Alice再次添加 `urgent`。
2. 列出所有元素。

**预期结果**：
- 集合仍然只包含一个 `urgent`（集合语义，不重复）。
- 但内部可能有两个不同的tag（ORSet的实现细节，对外不可见）。

---

### F-4：并发添加和删除同一元素（add-wins语义）

**前置条件**：`tags` 包含 `important`（由Alice在时刻T0添加）。

**操作步骤**：
1. Alice在时刻T1删除 `important`。
2. Bob在时刻T1（并发地，不知道Alice的删除）添加 `important`。
3. 合并两个操作后，查询 `important` 是否存在。

**预期结果**：
- `important` **存在**于集合中。
- 原因：ORSet的语义是"add wins"——Bob的添加操作产生了一个新的唯一tag，Alice的删除只移除了旧的tag，不影响Bob新添加的tag。
- 这是ORSet最核心的语义保证，必须验证。

---

### F-5：contains查询

**前置条件**：`tags` 包含 `urgent`，不包含 `low`。

**操作步骤**：
1. 查询 `urgent` 是否存在。
2. 查询 `low` 是否存在。

**预期结果**：
- 步骤1返回 exists = true。
- 步骤2返回 exists = false。

---

## 模块G：实时协作·LWWMap键值对

### G-1：设置和读取键值对

**前置条件**：文档 `doc1` 有 lww_map 字段 `config`。

**操作步骤**：
1. Alice设置 `config` 为 `{"theme": "dark", "lang": "zh"}`。
2. 读取 `config`。

**预期结果**：
- 返回的值包含 `theme = dark` 和 `lang = zh`。

---

### G-2：并发修改不同键

**前置条件**：`config` 当前为 `{"theme": "dark", "lang": "zh"}`。

**操作步骤**：
1. Alice设置 `config` 为 `{"theme": "light", "lang": "zh"}`（只改了theme）。
2. Bob设置 `config` 为 `{"theme": "dark", "lang": "en"}`（只改了lang）。
3. 读取 `config`。

**预期结果**：
- 如果实现为整体LWW：后写入者的整个值胜出（取决于时间戳）。
- 如果实现为per-key LWW（LWWMap的理想语义）：`theme = light`（Alice的更新），`lang = en`（Bob的更新），两个修改都保留。
- 当前实现为整体LWW，所以后写入者胜出。此处记录为已知限制。

---

## 模块H：实时协作·PNCounter计数器

### H-1：递增

**前置条件**：文档 `doc1` 有 pn_counter 字段 `score`，初始值为0。

**操作步骤**：
1. Alice递增1。
2. Alice递增3。
3. 读取值。

**预期结果**：
- 值为 4。

---

### H-2：递减

**前置条件**：`score` 当前值为 4。

**操作步骤**：
1. Alice递减2。
2. 读取值。

**预期结果**：
- 值为 2。

---

### H-3：多Agent并发递增（全部生效）

**前置条件**：`score` 当前值为 0。

**操作步骤**：
1. Alice递增5。
2. Bob递增3。
3. Charlie递增7。
4. 读取值。

**预期结果**：
- 值为 15（5 + 3 + 7）。
- 关键验证点：PNCounter的核心保证——每个Agent的增量独立累加，不会因并发而丢失任何一次操作。

---

### H-4：并发递增和递减

**前置条件**：`score` 当前值为 10。

**操作步骤**：
1. Alice递增5。
2. Bob递减3。
3. 读取值。

**预期结果**：
- 值为 12（10 + 5 - 3）。
- 无论操作到达顺序如何，结果相同。

---

### H-5：合并来自不同Agent的计数器状态

**前置条件**：两个独立的PNCounter副本，初始都为0。

**操作步骤**：
1. 副本A上：alice递增10，bob递增5。
2. 副本B上：alice递增3，charlie递增7。
3. 合并副本A和副本B。

**预期结果**：
- alice的正计数 = max(10, 3) = 10。
- bob的正计数 = max(5, 0) = 5。
- charlie的正计数 = max(0, 7) = 7。
- 总值 = 10 + 5 + 7 = 22。
- 关键验证点：合并是幂等的——再次合并同样的状态，结果不变。

---

## 模块I：实时协作·文档级别

### I-1：创建包含多种字段类型的文档

**前置条件**：无。

**操作步骤**：
1. 调用 `realtime_create_document`，doc_id 为 `board`，schema 为：
   ```
   title: lww_register
   body: rga
   members: or_set
   settings: lww_map
   view_count: pn_counter
   ```

**预期结果**：
- 返回 success = true。
- 文档包含5个字段，类型正确。

---

### I-2：获取文档快照

**前置条件**：文档 `board` 已创建并经过多次操作——title被设置为 `看板`，body有文本 `描述`，members包含 `alice` 和 `bob`，view_count为5。

**操作步骤**：
1. 调用 `realtime_get_document_snapshot`，doc_id 为 `board`。

**预期结果**：
- 返回 success = true。
- snapshot 包含所有5个字段的当前值。
- field_types 正确标注每个字段的类型。
- title = `看板`，body的文本 = `描述`，members包含alice和bob，view_count = 5。

---

### I-3：访问不存在的文档

**前置条件**：没有创建过 `nonexistent` 文档。

**操作步骤**：
1. 调用 `realtime_get_document_snapshot`，doc_id 为 `nonexistent`。

**预期结果**：
- 返回 success = false，错误信息表明文档不存在。

---

### I-4：访问不存在的字段

**前置条件**：文档 `board` 存在，但没有名为 `color` 的字段。

**操作步骤**：
1. 调用 `realtime_set_field`，doc_id 为 `board`，field_name 为 `color`，value 为 `red`。

**预期结果**：
- 返回 success = false，错误信息表明字段不存在。

---

### I-5：对错误类型的字段执行操作

**前置条件**：文档 `board` 的 `title` 字段类型为 lww_register。

**操作步骤**：
1. 调用 `realtime_edit_text`（RGA操作），doc_id 为 `board`，field_name 为 `title`。

**预期结果**：
- 返回 success = false，错误信息表明 `title` 不是 RGA 文本类型。

---

### I-6：文档持久化与恢复

**前置条件**：文档 `board` 经过多次操作，title = `看板`，view_count = 5。

**操作步骤**：
1. 确认 `realtime/.crdt_state/board.crdt.json` 文件存在于磁盘。
2. 模拟系统重启：销毁内存中的CRDTManager，重新创建并加载磁盘状态。
3. 读取 `board` 文档的 title 和 view_count。

**预期结果**：
- title = `看板`，view_count = 5。
- 所有字段状态与重启前完全一致。

---

## 模块J：工具调用分发器

### J-1：正常分发

**前置条件**：AgentFSTools 已初始化。

**操作步骤**：
1. 调用 `dispatch_tool_call`，tool_name 为 `save_to_my_workspace`，arguments 为 `{"filename": "test.md", "content": "hello"}`。

**预期结果**：
- 正确路由到 `tool_save_to_my_workspace` 方法。
- 返回 success = true。

---

### J-2：未知工具名

**前置条件**：AgentFSTools 已初始化。

**操作步骤**：
1. 调用 `dispatch_tool_call`，tool_name 为 `nonexistent_tool`，arguments 为 `{}`。

**预期结果**：
- 返回 success = false，错误信息包含 `未知工具`。

---

### J-3：参数缺失时的容错

**前置条件**：AgentFSTools 已初始化。

**操作步骤**：
1. 调用 `dispatch_tool_call`，tool_name 为 `save_to_my_workspace`，arguments 为 `{}`（缺少filename和content）。

**预期结果**：
- 不崩溃。
- 行为取决于实现：可能以空字符串作为默认值执行，或返回参数错误。
- 关键验证点：系统不会因为LLM传入不完整的参数而崩溃。

---

### J-4：工具定义格式正确性

**前置条件**：AgentFSTools 已初始化。

**操作步骤**：
1. 调用 `get_tool_definitions()`。
2. 检查返回的数组。

**预期结果**：
- 每个元素都是Dictionary，包含 `name`、`description`、`parameters` 字段。
- `parameters` 包含 `type`（值为 `object`）和 `properties`。
- 有 `required` 字段的工具，其 required 数组中的每个字段名都存在于 properties 中。
- 所有工具名称唯一，没有重复。

---

## 模块K：跨模块集成场景

### K-1：完整的研究→分析→写作工作流

**前置条件**：系统包含三个Agent：researcher、analyst、writer。

**操作步骤**：
1. Researcher保存调研数据到自己的工作区：`save_to_my_workspace("data.md", "调研数据...")`。
2. Researcher将数据交接给Analyst：`handoff_file("analyst", "data.md", "调研数据...", "请分析")`。
3. Analyst检查交接：`check_my_handoffs()`，确认收到1个文件。
4. Analyst读取交接文件：`read_handoff("researcher", "data.md")`。
5. Analyst在协作区创建分析报告：`collab_write("report.md", "分析结果...", "初稿", -1)`。
6. Writer读取协作区报告：`collab_read("report.md")`，得到v1。
7. Writer修改报告：`collab_write("report.md", "润色后的报告...", "润色", 1)`。
8. Analyst也基于v1修改（冲突）：`collab_write("report.md", "补充数据...", "补充", 1)`。
9. Analyst收到冲突，读取最新版本，合并后重新提交。
10. 最终查看历史，确认有3个版本。

**预期结果**：
- 每一步都返回预期的成功或冲突结果。
- 没有任何数据丢失。
- 最终报告包含Writer的润色和Analyst的补充。
- 历史记录完整，可追溯每次修改。

---

### K-2：实时协作看板 + 专属区草稿

**前置条件**：系统包含三个Agent：alice、bob、charlie。

**操作步骤**：
1. Alice创建实时协作看板：`realtime_create_document("kanban", {title: lww_register, tasks: or_set, done_count: pn_counter})`。
2. Alice设置标题：`realtime_set_field("kanban", "title", "Sprint 1")`。
3. 三个Agent各自在自己的工作区保存草稿。
4. 三个Agent同时向看板添加任务（ORSet）。
5. Alice完成一个任务，递增计数器。
6. Bob也完成一个任务，递增计数器。
7. Charlie获取看板快照。

**预期结果**：
- 看板标题为 `Sprint 1`。
- 任务集合包含三个Agent添加的所有任务（无遗漏）。
- 完成计数为2（Alice和Bob各递增1）。
- 每个Agent的专属区草稿互不影响。

---

### K-3：Agent读取其他Agent的工作区作为参考

**前置条件**：Researcher的工作区有 `notes.md`，Analyst的工作区有 `model.md`。

**操作步骤**：
1. Writer调用 `list_workspace_files("researcher")`，看到 `notes.md`。
2. Writer调用 `read_from_workspace("researcher", "notes.md")`，读取内容。
3. Writer调用 `list_workspace_files("analyst")`，看到 `model.md`。
4. Writer调用 `read_from_workspace("analyst", "model.md")`，读取内容。
5. Writer综合两份参考资料，保存到自己的工作区：`save_to_my_workspace("final_report.md", "综合报告...")`。

**预期结果**：
- Writer能成功读取其他Agent的文件。
- Researcher和Analyst的文件不受影响（只读访问）。
- Writer的产出保存在自己的工作区。

---

## 模块L：CRDT数学性质验证

这组测试验证CRDT的三个核心数学性质，是系统正确性的根基。

### L-1：交换律（Commutativity）

**对所有CRDT类型分别验证**：LWWRegister、RGA、ORSet、PNCounter。

**操作步骤**：
1. 创建两个独立的CRDT副本 X 和 Y，初始状态相同。
2. 在 X 上执行操作 Op_A。
3. 在 Y 上执行操作 Op_B。
4. 路径一：先将 Op_A 应用到 Y，再将 Op_B 应用到 Y。记录最终状态 S1。
5. 路径二：先将 Op_B 应用到 X，再将 Op_A 应用到 X。记录最终状态 S2。

**预期结果**：
- S1 == S2。
- 无论操作到达顺序如何，最终状态相同。

---

### L-2：结合律（Associativity）

**操作步骤**：
1. 三个独立副本 X、Y、Z，分别执行操作 A、B、C。
2. 路径一：先合并 X 和 Y 得到 XY，再合并 XY 和 Z，得到 S1。
3. 路径二：先合并 Y 和 Z 得到 YZ，再合并 X 和 YZ，得到 S2。

**预期结果**：
- S1 == S2。
- 合并的分组方式不影响最终结果。

---

### L-3：幂等性（Idempotency）

**操作步骤**：
1. 副本 X 执行了若干操作，得到状态 S。
2. 将 S 与自身合并，得到 S'。

**预期结果**：
- S == S'。
- 重复合并同一状态不改变结果。这保证了网络重传、消息重复不会导致错误。

---

### L-4：最终一致性（收敛性）

**操作步骤**：
1. 三个Agent各自独立执行一系列操作（不同的操作，不同的顺序）。
2. 以任意顺序将三个Agent的状态两两合并，直到所有Agent都拥有完整信息。
3. 比较三个Agent最终看到的状态。

**预期结果**：
- 三个Agent的最终状态完全相同。
- 这是CRDT最重要的保证：只要所有操作最终都被所有节点收到，最终状态一定收敛。

---

## 测试覆盖矩阵

| 模块 | 正常路径 | 边界条件 | 错误处理 | 并发场景 | 数学性质 |
|---|---|---|---|---|---|
| A 专属区 | A-1,2,3,4,7 | A-8 | A-5,6 | — | — |
| B 交接区 | B-1,2,4 | B-3,5 | — | — | — |
| C 版本控制 | C-1,2,5 | C-7,8 | C-3,4 | C-3 | — |
| D LWW | D-1 | D-3 | — | D-2 | L-1,2,3 |
| E RGA | E-1,2,3,4 | E-7 | — | E-5,6 | L-1,2,3 |
| F ORSet | F-1,2,5 | F-3 | — | F-4 | L-1,2,3 |
| G LWWMap | G-1 | — | — | G-2 | L-1,2,3 |
| H PNCounter | H-1,2 | — | — | H-3,4,5 | L-1,2,3 |
| I 文档级 | I-1,2 | I-3,4,5 | I-3,4,5 | — | — |
| J 分发器 | J-1,4 | J-3 | J-2 | — | — |
| K 集成 | K-1,2,3 | — | K-1(冲突) | K-2 | — |
| L 数学性质 | — | — | — | — | L-1,2,3,4 |

**总计：约50个测试用例**，覆盖正常流程、边界条件、错误处理、并发场景和CRDT数学性质五个维度。