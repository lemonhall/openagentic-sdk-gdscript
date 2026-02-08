# v104 index

Goal: 在 VR Offices 的聊天 overlay 中加入麦克风 ASR（阿里百炼）语音输入闭环：录音 → 转写 → 填入/发送 → NPC 对话或群聊广播；全程可配置、可降级、可回归测试。

## Artifacts

- PRD: `docs/prd/2026-02-08-vr-offices-asr-aliyun-bailian.md`
- Plan: `docs/plan/v104-vr-offices-asr-aliyun-bailian.md`

## Milestones

| Milestone | Scope | Verify | Status |
|---|---|---|---|
| M1 | `DialogueOverlay` 增加 Mic UI + 状态机 + 可注入 ASR client（不依赖真实麦克风/外网） | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_asr_overlay_ui.gd -TimeoutSec 240` | todo |
| M2 | Godot 4.6 麦克风采集与设备选择 wiring（可降级、可配置） | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_asr_audio_capture_adapter.gd -TimeoutSec 240` | todo |
| M3 | 百炼 ASR HTTP 集成（mock transport + 真实配置开关） | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/projects/vr_offices/test_vr_offices_bailian_asr_client.gd -TimeoutSec 240` | todo |
| M4 | Suites stay green | `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite vr_offices -TimeoutSec 240` | todo |

## Evidence

- (pending)

