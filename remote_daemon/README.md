# openagentic_remote_daemon (Rust)

这是 OpenAgentic 的 **remote 端常驻 daemon**：通过 IRC 频道接收 OA1 `REQ`，执行（或回显）命令后返回 OA1 `RES/ERR`。

## 1) 快速开始

在 `remote_daemon/` 目录运行：

```bash
cargo run -- --host <irc_host> --port <irc_port>
```

启动后会打印类似信息：

- `Device code: ABCD1234`
- `Data dir: .../openagentic_remote/<instance>/`
- `IRC: ... as <nick>`（其中 `<nick>` 是 daemon 在 IRC 上的 nickname，某些服务器限制 `<=9`；可用 `--nick` 覆盖）
- `Executor: echo`（默认不执行命令，只回显）

把输出的 `Device code` 填到游戏里桌子的右键菜单：

- 右键桌子 → `绑定设备码…` → 输入 device code

配对成功后（daemon 每隔一段时间 `LIST` 轮询）会自动 `JOIN` 形如 `..._dev_<CODE>...` 的频道；此时 NPC 绑定桌子后才会看到 `RemoteBash` 工具。

## 2) 真实执行 Bash（危险）

默认 executor 为 `echo`，不会执行任何命令。要启用真实执行：

```bash
cargo run -- --host <irc_host> --port <irc_port> --enable-bash
```

或使用环境变量：

```bash
OA_REMOTE_ENABLE_BASH=1 cargo run -- --host <irc_host> --port <irc_port>
```

安全提示：

- OA1 over IRC **没有鉴权**；启用 `--enable-bash` 等同于把远端 bash 暴露给“能在该频道发消息的人”。
- 只在你完全信任的 IRC 服务/频道内使用。

## 3) 常用参数 / 环境变量

查看帮助：

```bash
cargo run -- --help
```

等价的 CLI 参数与环境变量（节选）：

- `--host` / `OA_IRC_HOST`（默认 `127.0.0.1`）
- `--port` / `OA_IRC_PORT`（默认 `6667`）
- `--password` / `OA_IRC_PASSWORD`（可选）
- `--nick` / `OA_IRC_NICK`（默认从 device code 派生）
- `--poll-seconds` / `OA_REMOTE_POLL_SECONDS`（默认 `30`）
- `--instance` / `OA_REMOTE_INSTANCE`（默认 `default`，用于隔离多实例的数据目录）
- `--data-home` / `OA_REMOTE_DATA_HOME`（自定义数据根目录）
- `--device-code` / `OA_REMOTE_DEVICE_CODE`（覆盖并写入 `device_code.txt`）
- `--bash-timeout-sec` / `OA_REMOTE_BASH_TIMEOUT_SEC`（默认 `30`）

## 4) 多实例（同一台机器启动多个 daemon）

给每个 daemon 指定不同 `--instance`（或不同 `--data-home`），让每个实例有独立的：

- `device_code.txt`
- 未来的任何持久化数据

示例：

```bash
cargo run -- --host <irc_host> --port <irc_port> --instance desk_1
cargo run -- --host <irc_host> --port <irc_port> --instance desk_2
```

## 5) 限制/现状

- 目前是明文 TCP IRC（不支持 TLS/SASL）。
- 当前连接断开会退出进程（没有自动重连）；建议用 systemd/supervisor 做自动重启。
- 捕获输出有上限（见源码 `max_capture_bytes` / `max_response_bytes`），超出会截断并带 `...[truncated]...`。
