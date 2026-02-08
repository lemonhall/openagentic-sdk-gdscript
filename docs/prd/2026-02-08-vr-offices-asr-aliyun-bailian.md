# VR Offices: 麦克风 ASR（阿里百炼）PRD

## Vision

在 VR Offices 的聊天入口（NPC 对话 overlay、Meeting Room 群聊 overlay）中加入“按住说话/点击录音”的语音输入能力：游戏从麦克风采集音频，调用 **阿里百炼（BaiLian）ASR API** 转写为文本，将结果填入聊天输入框并可一键发送，从而实现“用语音与 NPC 对话”。

## Context（现状）

- 当前 VR Offices 已有两类聊天 UI：
  - `DialogueOverlay`：NPC 1:1 对话
  - Meeting Room 群聊 overlay：复用同一个 `DialogueOverlay` 皮肤，但走 `VrOfficesMeetingRoomChatController` 的群聊 broadcast
- “麦克风”目前指 Meeting Room 场景中的交互物体（打开群聊 overlay），**不含真实音频采集**。

## Requirements

### REQ-001 — 聊天输入支持语音转写（基础闭环）

- 在 `DialogueOverlay` 中提供一个 **Mic 按钮**：
  - 按住说话（Press-to-talk）或点击开始/停止录音（Toggle）二选一（见 Open Questions）。
  - 录音结束后触发 ASR 请求。
- ASR 成功后：
  - 转写文本写入输入框（可编辑）。
  - 支持“自动发送”开关：开启时，ASR 结束自动提交消息；关闭时仅填入输入框等待用户确认发送。

### REQ-002 — 麦克风设备选择与记忆

- 支持列出系统可用的输入设备并允许选择：
  - 默认使用系统默认输入设备。
  - 选择结果持久化到本地配置（随 save 或全局设置，见 Open Questions）。
- 必须有可靠降级：
  - 获取不到设备列表 / headless / 无权限时，Mic 功能显示不可用并给出可理解提示，不影响文字聊天。

### REQ-003 — 阿里百炼 ASR 接入（可配置、可替换）

- 通过 HTTP(S) 调用百炼 ASR API 获取转写结果。
- 关键参数可配置（至少包含）：
  - API endpoint / region（如有）
  - API Key / token（不得写入仓库；仅本地环境变量或用户配置）
  - 模型/语种（至少支持 `zh-CN`，并与 `VrOffices.culture_code` 的默认一致）
  - 音频格式（采样率/位深/声道）与编码方式（raw wav / pcm16 / base64 / multipart 等，待文档确定）

### REQ-004 — UX：可见状态与可取消

- 录音与转写必须有明确状态：
  - Recording（录音中）
  - Transcribing（转写中）
  - Error（失败）
- 用户可以取消：
  - 录音中取消（丢弃音频，不发请求）
  - 转写中取消（若 API 不支持取消，则 UI 需要至少中止后续“自动发送”并忽略晚到结果）

### REQ-005 — 隐私与存储边界（默认安全）

- 默认不持久化原始音频到磁盘（除非显式开启 debug 选项）。
- 明确告知：语音会发送到百炼服务进行转写（“外部服务”提示）。
- 日志中不得输出敏感信息（token、完整音频 payload、用户隐私内容等）。

### REQ-006 — 自动化测试（可回归）

必须补齐/新增测试，覆盖至少：

- `DialogueOverlay` 存在 Mic UI，并在 busy 状态下禁用录音/发送冲突。
- ASR 成功路径：模拟 ASR client 返回文本 → 输入框被填充（以及自动发送开关的行为）。
- 失败/取消路径：模拟失败 → 错误提示出现且不会提交消息。

> 说明：测试不得依赖真实麦克风与外网；应通过可注入的“音频采集接口”和“ASR transport”做 fake/mock。

## Non-Goals

- 语音唤醒词、连续对话、长时间后台监听。
- 回声消除、降噪、语音活动检测（VAD）、说话人分离等音频处理（后续里程碑再讨论）。
- 多人实时语音通话或空间语音。
- 让 NPC 输出 TTS（本 PRD 只做 ASR 输入）。

## Open Questions（需要你贴百炼文档后定稿）

1) 百炼 ASR 是否支持 **流式识别**（WebSocket/SSE）与 **非流式**（一次性上传音频）？本版本优先哪一种？
2) 百炼要求的音频格式（采样率/声道/封装）是什么？是否接受 `wav`？是否要求 `pcm16le`？
3) 认证方式与安全最佳实践（API Key、STS token、签名等）具体是什么？我们倾向用环境变量还是游戏内设置面板？
4) 首个里程碑范围：仅 NPC 1:1 对话 overlay 支持 ASR，还是 Meeting Room 群聊 overlay 也要同样支持？
5) 交互形态：Press-to-talk（按住） vs Toggle（点击开始/停止），你更希望哪一个作为默认？

