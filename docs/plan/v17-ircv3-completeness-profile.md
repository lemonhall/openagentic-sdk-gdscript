# v17 Review — “IRCv3 完整实现”定义与收敛目标（Profile）

## Reality Check（愿景 vs 现实）

“IRCv3”不是一个单一协议版本，而是一组可选扩展（CAP 机制 + N 个 capability 规范）。因此在工程上，“IRCv3 完整实现”如果按字面理解会变成**无边界**目标：永远可以追加更多扩展与兼容性细节。

当前 v17 已实现：

- TLS 接入（非真实网络集成测试，仅 API/分支覆盖）。
- IRCv3 message tags：解析 + 反转义 + 结构保留（`IrcMessage.tags`）。
- CAP 基础协商：`LS/REQ/ACK/NAK`（并已覆盖 multiline、`cap=value`、cap list 在 params 中的变体）。
- SASL PLAIN：`AUTHENTICATE` payload 分片（400 chars）与结束规则。

结论：**v17 并未“完整实现 IRCv3（无限集）”**，但已达到“IRCv3 basics”。

## Updated Goal（把“完整”变成可验收的目标）

将 v17 的“IRCv3 完整”收敛为一个明确 Profile（可测、可验收、可扩展）：

### IRCv3 Profile A（v17 的 DoD）

目标：实现 CAP 协商与消息元数据的**可靠互操作**，覆盖常见网络与服务端实现差异。

- Message tags（解析 + 反转义 + 保留）。
- CAP grammar 支持：
  - `LS/REQ/ACK/NAK/END`（已做）
  - `LIST`（查询当前启用）
  - `NEW/DEL`（服务端动态通知）
  - multiline（`*`）、`cap=value`、cap list trailing 与 param-form 都要支持（已部分覆盖，继续补齐）
- SASL：
  - PLAIN happy-path + failure numerics（903/904..907）处理
  - `AUTHENTICATE` 400 字符分片 + 400n 的 `AUTHENTICATE +` 终止（已做）
- 不引入真实网络依赖：仍采用 in-memory scripted peer 测试。

### Profile B（后续版本：不在 v17 强行塞）

把“更广泛 IRCv3”拆到后续版本（例如 v19）：

- `cap-notify`、`labeled-response`、`batch`、`message-ids`、`echo-message`、`server-time` 等扩展（按价值排序逐个切片）。
- Outgoing message tags 格式化与 roundtrip。
- STARTTLS/证书验证策略与真实网络集成测试（环境允许时）。

## Next Slice (本轮要做什么)

- 补齐 CAP `LIST/NEW/DEL` 的实现与测试，作为 Profile A 的“语法完整性”里程碑。

