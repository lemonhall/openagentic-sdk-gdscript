# v51 — Dialogue Attachment UI Plan

## Goal

让玩家在 `DialogueOverlay` 里“像聊天软件一样”直接发图片/音频/视频（先以图片为主），支持：

- 一次选多个文件
- 拖拽多个文件
- 队列 + 进度 + 取消 + 失败提示

## PRD Trace

- REQ-010, REQ-011, REQ-012

PRD: `docs/prd/2026-02-04-vr-offices-multimedia-messages.md`

## Scope

In scope:

- `DialogueOverlay.tscn/gd` 增加附件 UI：
  - Attach 按钮
  - 队列列表（文件名/类型/大小/进度/状态）
    - 进度允许先做“不可测的 indeterminate progress bar”（有明确 uploading 状态即可），不强求真实百分比
  - per-item cancel + cancel-all
- 上传与发送：
  - 读取本机文件 bytes → POST `/upload`（bearer） → 得到 meta → 生成 `OAMEDIA1`
  - 若 IRC/通道需要，发送 `OAMEDIA1F` 分片（对 Dialogue 本身可直接发 `OAMEDIA1`，但仍共享同一编码逻辑）
  - 为了让“我自己发出去的图片也能在聊天里立刻显示”，上传成功后应把 bytes 写入 per-save cache（`user://openagentic/saves/<save_id>/cache/media/`）
- 安全：
  - 聊天内容不含 token
  - `name` 使用 basename（不含绝对路径）
  - 上传前做最小校验：扩展名→mime 映射（只允许 png/jpg/jpeg/mp3/wav/mp4）与 size 上限（按 PRD）

Out of scope:

- 音频/视频播放器 UI（只保证上传与引用发送）
- 全量 UI 美术优化（先做到清晰、可用）

## Acceptance (DoD)

1) 在对话框中可通过 Attach 多选文件并开始队列上传；队列中每个项目都有状态与进度。
2) 拖拽多个文件到对话框也会进入同一队列。
3) 任意一个文件上传失败不会导致队列整体崩溃；失败项可重试/跳过（至少跳过）。
4) 不支持的类型/超过大小限制的文件在“上传前”会被拒绝并给出明确错误（不进入上传请求）。
5) 发送到 OpenAgentic 的文本中不包含 bearer token，且不包含本机绝对路径（只允许 basename）。
6) 图片上传成功后，图片 bytes 会落盘到 per-save cache，且聊天中显示缩略图（不要求手动刷新）。
7) Headless 回归测试可验证：多文件队列、状态机、以及最终发出的 `OAMEDIA1` 行。

## Files

Modify:

- `vr_offices/ui/DialogueOverlay.tscn`
- `vr_offices/ui/DialogueOverlay.gd`
- `vr_offices/ui/VrOfficesMediaCache.gd`

Add:

- `vr_offices/ui/VrOfficesAttachmentQueue.gd`（队列状态机：pending/uploading/sent/failed/cancelled）
- `vr_offices/ui/VrOfficesMediaUploader.gd`（HTTP 上传，支持可注入 transport 便于测试）
- `vr_offices/core/media/VrOfficesMediaConfig.gd`（从环境变量读取 media base/token；避免散落在 UI 里）
- `tests/projects/vr_offices/test_vr_offices_dialogue_attachments_ui.gd`
- `tests/projects/vr_offices/test_vr_offices_dialogue_attachments_upload.gd`
 - `docs/vr_offices/multimedia_messages.zh-CN.md`

## Steps (塔山开发循环)

### Slice A — Queue state machine (RED→GREEN)

1) **Red**：新增 `test_vr_offices_dialogue_attachments_ui.gd`：
   - 模拟添加 3 个“待上传”条目
   - 状态推进：pending → uploading → sent/failed
   - 取消：单条取消与全取消
2) **Green**：实现 `VrOfficesAttachmentQueue.gd`
3) **Verify**：

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_attachments_ui.gd
```

### Slice B — Upload + send OAMEDIA1 (RED→GREEN)

1) **Red**：新增 `test_vr_offices_dialogue_attachments_upload.gd`：
   - 用可注入 transport 模拟 `/upload` 返回 meta
   - 断言生成的 `OAMEDIA1` 不含 token/绝对路径
   - 断言多文件按顺序发送（队列）
2) **Green**：实现 `VrOfficesMediaUploader.gd` + `DialogueOverlay` 集成
3) **Verify**：

```bash
scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_attachments_upload.gd
```

### Slice C — Docs (still GREEN)

1) 更新玩家文档：`docs/vr_offices/multimedia_messages.zh-CN.md`
   - 说明：在 `DialogueOverlay` 里用 Attach/拖拽发送多媒体
   - 说明：支持的格式与大小上限
   - 说明：失败提示与常见排错（缺 env / token / 服务不可达）
2) **Verify**：

```bash
rg -n "附件|Attach|拖拽" docs/vr_offices/multimedia_messages.zh-CN.md
```

## Risks

- Godot 拖拽文件事件在不同平台的差异：优先实现最基础、可测试的逻辑层（队列与上传），UI 事件仅做薄适配。
- 文件对话框多选与权限：测试侧通过“注入文件列表”验证核心行为，避免依赖真实文件对话框。
