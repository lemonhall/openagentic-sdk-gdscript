# VR Offices 多媒体消息（v51）使用指南（含：聊天框直接发送附件）

这份文档面向“人类玩家/开发者”，介绍如何在 VR Offices 里使用 **v51** 的多媒体消息能力（图片为主，音频/视频可发送但 UI 播放仍分期），以及你能期待什么、暂时做不到什么。

你可以把版本差异理解成：

- v50：把“多媒体在纯文本通道里怎么安全地传递”这件事做扎实（协议、服务、工具、IRC 分片、E2E）
- v51：把玩家侧体验补齐：**在 NPC 对话框里直接点“Attach/附件”或拖拽文件发送**

## 这套能力解决什么问题

IRC 和对话系统本质是“纯文本通道”，无法直接传 PNG/MP3/MP4。v50 的做法是：

1) **把媒体文件上传到一个独立的媒体服务**（不和 `proxy/` 放一起）；
2) 聊天里只发送一个**媒体引用**（文本行）：`OAMEDIA1 ...`（或分片 `OAMEDIA1F ...`）；
3) 接收端（尤其是 agent）拿到引用后，通过工具把媒体**下载到自己的安全目录**（NPC workspace），得到一个**相对路径**供后续使用；
4)（可选）玩家 UI 侧可以把媒体落盘到 `user://.../cache/` 并展示（v50 目前仅实现“从缓存展示图片”，自动下载展示会在后续版本补齐）。

关键安全点：

- **访问媒体必须带 bearer token**（上传/下载都需要）；token **不进入聊天内容**，就算 `OAMEDIA1` 文本被转发也不能直接下载。

## 支持的媒体类型（v50/v51）

- 图片：`image/png`、`image/jpeg`
- 音频：`audio/mpeg`（mp3）、`audio/wav`
- 视频：`video/mp4`

注意：v50 的 VR Offices `DialogueOverlay` 目前只做了“图片从本地缓存渲染”；音频/视频的 UI 播放不在 v50 交付范围。

## v51：在 NPC 聊天框里直接发送图片/音频/视频（推荐）

从 v51 开始，`DialogueOverlay` 里会有一个明显的 `Attach` 按钮，并且支持把文件**拖拽**到对话框里。

它的工作流程大致是：

1) 你选择/拖入文件；
2) 客户端在上传前做最小校验（类型/大小）；
3) 上传到独立媒体服务（带 bearer token）；
4) 生成并发送一行 `OAMEDIA1 ...` 给 NPC/agent（聊天里**不会**包含 token，也不会包含你的本机绝对路径）；
5) 为了让“我自己发出去的图片也能立刻显示”，客户端会把文件 bytes 落盘到 `user://.../cache/media/`（并做 `bytes/sha256` 校验）。

### 你怎么用（一步步）

前提：你已经完成下方「准备工作」（启动媒体服务 + 配置环境变量）。

在游戏里与某个 NPC 打开对话框后：

1) 点击 `Attach`
2) 选择一个或多个文件（可多选）
3) 你会看到一个“附件队列”：每个文件会显示状态（uploading/sent/failed/cancelled 等）
4) 上传成功后，这条消息会自动以 `OAMEDIA1 ...` 的形式发送给 NPC/agent
5) 如果是图片，你会在聊天气泡里看到缩略图（来自本地缓存）

另外，你也可以把文件直接拖进对话框：会进入同一个队列。

### 常见失败提示（你会看到的原因）

- `MissingMediaConfig`：你没有配置 `OPENAGENTIC_MEDIA_BASE_URL` / `OPENAGENTIC_MEDIA_BEARER_TOKEN`，或者为空
- `UnsupportedType`：文件类型不在白名单（只允许 png/jpg/jpeg/mp3/wav/mp4）
- `TooLarge`：超过大小限制（图片≤8MiB，音频≤20MiB，视频≤64MiB）

## v50 回顾：为什么当时 NPC 聊天框 UI “没变”（历史原因）

v50 交付的是“多媒体传输与安全链路”的底座（协议、工具、服务、IRC 分片、E2E），**没有**在 `DialogueOverlay` 里新增“选择文件/上传/插入媒体”的按钮。

所以你在游戏里看到的仍然是：

- 一个输入框 + `Send` 按钮（发文本）

你要发送图片给 NPC/agent，v50 的方式是：

- **先在外部把文件上传**，得到一行 `OAMEDIA1 ...`
- **再把这行文本粘贴进聊天框**发送

这也是为什么 UI 不变但功能已经可用：多媒体在 v50 被表示为“可解析的文本引用”。

## 准备工作

### 1) 启动媒体服务（单独进程）

在仓库根目录运行：

```bash
export OPENAGENTIC_MEDIA_BEARER_TOKEN="dev-token"
export OPENAGENTIC_MEDIA_STORE_DIR="/tmp/oa-media"
node media_service/server.mjs --host 127.0.0.1 --port 8788
```

健康检查（可选）：

```bash
curl -s http://127.0.0.1:8788/healthz
```

### 2) 给 VR Offices / agent 配置媒体服务地址与 token

在启动 VR Offices 的环境里设置：

- `OPENAGENTIC_MEDIA_BASE_URL`：例如 `http://127.0.0.1:8788`
- `OPENAGENTIC_MEDIA_BEARER_TOKEN`：例如 `dev-token`

要求：

- 这个 `OPENAGENTIC_MEDIA_BASE_URL` 必须对“接收端”可达（同机/局域网/公网均可，但要能连上）。
- **不要把 token 复制粘贴到聊天里**（它只应该存在于本地环境变量/配置里）。

## 玩家 →（IRC）→ agent：发送一张图片给对面 agent

这是 v50 最可靠的一条链路：你把媒体引用发到 IRC，对面 agent 用工具下载到自己的 workspace。

### 步骤 A：上传并发送 `OAMEDIA1` 到 IRC

使用脚本发送端（推荐，最省事）：

```bash
export OPENAGENTIC_MEDIA_BASE_URL="http://127.0.0.1:8788"
export OPENAGENTIC_MEDIA_BEARER_TOKEN="dev-token"

python3 scripts/oa_media_sender.py \
  --file /path/to/a.png \
  --irc-host <your-irc-host> \
  --irc-port 6667 \
  --irc-channel "#test" \
  --irc-nick "oa_sender"
```

你会在终端看到一行 `OAMEDIA1 ...`，脚本会自动：

- 上传文件到媒体服务
- 生成 `OAMEDIA1 ...`
- 如果 IRC 单行长度不够，会自动用 `OAMEDIA1F ...` 分片发送（避免把 base64/JSON 直接硬切坏）

如果你只想生成引用、不发 IRC：

```bash
python3 scripts/oa_media_sender.py --file /path/to/a.png --print-only
```

## 玩家 → NPC（直接对话框）：如何从 NPC 聊天框发送图片

NPC 聊天框不是 IRC，它只是把你输入的文本交给 OpenAgentic（NPC/agent）。

v51 推荐：直接用 `Attach`/拖拽发送（见上方「v51：在 NPC 聊天框里直接发送…」）。

如果你想走“纯手工、可控”的方式（任何版本都适用），步骤如下：

1) 先生成一行 `OAMEDIA1 ...`（终端会输出这行文本）：

```bash
export OPENAGENTIC_MEDIA_BASE_URL="http://127.0.0.1:8788"
export OPENAGENTIC_MEDIA_BEARER_TOKEN="dev-token"
python3 scripts/oa_media_sender.py --file /path/to/a.png --print-only
```

2) 复制终端输出的整行 `OAMEDIA1 ...`
3) 粘贴到 VR Offices 的 NPC 对话框输入框里，点 `Send`
4) 再补一句明确指令让 NPC 去取文件（否则它未必会主动调用工具），例如：
   - “请用 `MediaFetch` 下载我刚发的 `OAMEDIA1` 图片到你的 workspace，然后描述图片内容。”

### 步骤 B：让对面 agent 把媒体下载到自己的 workspace

对面 agent 侧提供了两个工具（OpenAgentic 默认工具集里）：

- `MediaUpload`：从 NPC workspace 选文件上传，返回 `OAMEDIA1 ...`
- `MediaFetch`：给定 `OAMEDIA1 ...`，下载到 NPC workspace，返回 workspace 相对路径

对面 agent 收到你发的 `OAMEDIA1` 后，通常你需要在对话里明确一句：

- “请把我刚发的媒体下载到你的 workspace 并告诉我你保存到哪里，再基于它继续。”

（v50 没有强制让 agent 自动下载；它是否调用 `MediaFetch` 取决于模型行为/提示词。）

## agent →（IRC）→ 玩家：对面发媒体给你（v50 的现状）

这条链路在“传输与落盘”层面是可验证的（见下方 E2E），但玩家 UI 的“自动下载并展示”在 v50 还不完整：

- 对面 agent 可以 `MediaUpload` 得到 `OAMEDIA1 ...` 并通过 IRC 发给你；
- VR Offices 的 `DialogueOverlay` 能识别 `OAMEDIA1 ...`，但 **只会尝试从本地缓存目录加载图片**；
- v50 还没有实现：收到 `OAMEDIA1` 后自动去媒体服务下载到 `user://.../cache/media/` 再展示。

### 如果你就是想在 UI 里看到图片（手工办法）

`DialogueOverlay` 的图片缓存命名规则是：

`user://openagentic/saves/<save_id>/cache/media/<id>_<sha256>.(png|jpg)`

也就是说，只要你把对应文件放到这个路径，UI 就能显示（并会校验 `bytes/sha256`）。

## 手工工具（可选）：Tk 小窗口

如果你更喜欢点选文件：

```bash
python3 scripts/oa_media_sender_tk.py
```

你可以：

- 选择文件 → 上传 → 生成 `OAMEDIA1`；
- 如果填写了 IRC host，会顺便把引用发到 IRC。

## 自检（开发者/CI）——一条命令验证整条链路

v50 提供了一个 headless 的 e2e 测试，不依赖公网 IRC，也不依赖 UI 截图：

```bash
scripts/run_godot_tests.sh --one tests/e2e/test_multimedia_flow.gd
```

它会验证：

- `MediaUpload` 生成 `OAMEDIA1`（且不泄露 token）
- IRC 分片 `OAMEDIA1F` 可重组回 `OAMEDIA1`
- `MediaFetch` 下载到 workspace，落盘 bytes 完全一致

## 常见问题（FAQ）

### 1) 为什么我要跑一个媒体服务？不能直接把图片塞进聊天里吗？

IRC/对话日志长度与隐私都不可控，直接内嵌 base64 会导致：

- 消息过长/被截断/无法重组
- 日志膨胀
- 更难做安全控制

所以 v50 采用“引用 + 受控下载”的方式。

### 2) token 泄露了怎么办？

token 一旦泄露，持有人就能上传/下载媒体。建议：

- 只在本机环境变量里配置
- 需要时旋转（换一个 token）

### 3) 我能发视频/音频吗？

媒体服务层面支持 MP3/WAV/MP4 的允许列表与大小限制；但 VR Offices 的对话 UI 侧在 v50 只实现了图片缓存渲染，音频/视频播放属于后续版本范围。
