# v104 — VR Offices: ASR（阿里百炼）语音输入

## Problem

目前 VR Offices 聊天完全依赖键盘输入；Meeting Room 的“mic”仅是交互物体/群聊入口，并不具备真实语音能力。我们需要一个可回归的语音输入闭环，让玩家能用麦克风说话并通过 ASR 转写为文本，与 NPC 对话（以及可选地在 meeting room 群聊中广播）。

## Constraints / Assumptions

- Godot 版本：4.6（strict 模式，避免 `null` 推断类型问题）。
- 测试环境可能是 headless；不能依赖真实麦克风设备，也不能依赖外网。
- 百炼 API 细节（认证/格式/是否流式）需要你贴文档后定稿；本计划先搭“可替换 client + mock transport”骨架，避免返工。

## Godot 4.6 麦克风接入调查结论（用于计划）

在 Godot 4.x 的常见做法：

1) **设备选择**
   - 通过 `AudioServer.get_input_device_list()` 获取输入设备列表（`Array[String]`）。
   - 通过设置 `AudioServer.input_device`（字符串设备名）切换当前输入设备。
2) **采集音频**
   - 创建一个 `AudioStreamPlayer`，其 `stream` 设为 `AudioStreamMicrophone`。
   - 将该 player 输出到一个专用 Audio Bus（例如 `ASR`）。
   - 在该 bus 上添加 `AudioEffectCapture`，从中 `get_buffer()` 拉取采样。
3) **格式转换**
   - Godot 采样通常是 float（-1..1）且可能为 stereo；ASR 往往需要 mono `pcm16le` 以及固定采样率（常见 16k）。
   - 需要 downmix + clamp + 转 int16，并按百炼要求做 resample（若要求采样率与设备不同）。

> 说明：上述 API 名称将在实现时通过小型适配层封装，并在测试中用 fake 采集器替代，避免因设备/平台差异导致不稳定。

## Plan (TDD / 塔山执行切片)

### Slice A — Overlay 语音输入 UI（不接真实麦克风）

**Goal:** 先把 UI/状态机/接口注入打通：点击/按住 → 进入 recording 状态（fake）→ 调用 fake ASR → 写入 input 或自动发送。

**Files (planned):**
- Modify: `vr_offices/ui/DialogueOverlay.tscn`（新增 Mic 按钮、状态提示控件）
- Modify: `vr_offices/ui/DialogueOverlay.gd`（状态机、取消、busy/禁用逻辑、ASR 注入点）
- Create: `vr_offices/core/asr/VrOfficesAsrService.gd`（抽象服务：start/stop/cancel，返回 transcript）
- Create: `vr_offices/core/asr/VrOfficesAsrClient.gd`（接口/协议：transcribe(bytes, cfg)）
- Test: `tests/projects/vr_offices/test_vr_offices_asr_overlay_ui.gd`

**DoD (hard):**
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_asr_overlay_ui.gd -TimeoutSec 240` → PASS

### Slice B — 音频采集适配层（Godot 麦克风 → PCM）

**Goal:** 用一个可注入的 adapter 隔离 Godot 音频采集细节；生产环境用真实采集器，测试用 fake buffer。

**Files (planned):**
- Create: `vr_offices/core/asr/audio/VrOfficesMicCapture.gd`（接口：start/stop/read_pcm16()）
- Create: `vr_offices/core/asr/audio/VrOfficesGodotMicCapture.gd`（AudioStreamMicrophone + AudioEffectCapture 实现）
- Create: `vr_offices/core/asr/audio/VrOfficesPcmResampler.gd`（必要时做 downmix/resample/pcm16）
- Test: `tests/projects/vr_offices/test_vr_offices_asr_audio_capture_adapter.gd`

**DoD (hard):**
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_asr_audio_capture_adapter.gd -TimeoutSec 240` → PASS

### Slice C — 百炼 ASR client（mock transport 优先）

**Goal:** 在不访问外网的前提下，完成请求构造/响应解析/错误处理；真实调用通过配置开关启用。

**Files (planned):**
- Create: `vr_offices/core/asr/providers/VrOfficesBailianAsrClient.gd`
- Create: `vr_offices/core/net/VrOfficesHttpTransport.gd`（可注入 transport，便于 mock）
- Modify: `vr_offices/core/save/VrOfficesSaveController.gd` 或 settings 模块（存储 endpoint/模型/开关；具体落点待确认）
- Test: `tests/projects/vr_offices/test_vr_offices_bailian_asr_client.gd`

**DoD (hard):**
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_bailian_asr_client.gd -TimeoutSec 240` → PASS

### Slice D — 端到端（离线）与回归

**Goal:** 在 vr_offices suite 中验证“打开 overlay → 录音 → fake transcript → 自动填入/发送 → chat history 出现消息”的闭环。

**Files (planned):**
- Test: `tests/projects/vr_offices/test_vr_offices_asr_end_to_end_offline.gd`

**DoD (hard):**
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` → EXIT=0

## Risks

- 平台差异：Windows/macOS/Linux 的输入设备命名与权限行为不同。
- 采样率/格式：百炼格式要求与 Godot 原始采集不一致导致需要 resample，需注意性能与正确性。
- UI/控制权：overlay 已有 busy/附件上传/历史渲染等逻辑，新增录音状态需避免引入“卡死/不可关闭/竞态”。

## Next Step（等待你贴百炼文档后定稿）

把百炼 ASR 文档贴出来后，我们会把 Slice C 的请求格式、认证方式、音频编码、是否流式等细节补成“硬 DoD”，并更新 PRD 的 Open Questions 为明确结论，然后再开工实现。

