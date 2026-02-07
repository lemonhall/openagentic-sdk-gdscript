# Godot 测试实战手册（给 Win + Codex CLI 同学）

> 目标：让你在 **Windows + Codex CLI + Godot 4.6** 环境里，能稳定地写、跑、修 Godot 自动化测试。

## 1) 先把跑测环境固定住（最重要）

优先使用仓库自带脚本，不要手写一长串命令。

### PowerShell（推荐）

```powershell
# 1) 配置 Godot 控制台 exe（注意是 console 版）
$env:GODOT_WIN_EXE = "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"

# 2) 给每个测试加超时，防卡死
$env:GODOT_TEST_TIMEOUT_SEC = "120"

# 3) 先跑一个最小测试，确认环境通
scripts\run_godot_tests.ps1 -One tests\addons\openagentic\test_sse_parser.gd
```

### 常用命令

```powershell
# 跑单测（开发时最常用）
scripts\run_godot_tests.ps1 -One tests\projects\vr_offices\test_vr_offices_smoke.gd

# 跑一个 suite
scripts\run_godot_tests.ps1 -Suite vr_offices

# 看更多日志
scripts\run_godot_tests.ps1 -One tests\projects\vr_offices\test_vr_offices_smoke.gd -ExtraArgs --verbose
```

---

## 2) 这个仓库里，测试该放哪

- SDK/OpenAgentic 核心：`tests/addons/openagentic/`
- VR Offices（主产品）：`tests/projects/vr_offices/`
- demo_rpg：`tests/projects/demo_rpg/`（除非明确要求，一般别扩）

命名规则：`test_*.gd`。

---

## 3) 写一个 Godot 测试的最小模板

这个仓库常用 `extends SceneTree` + `tests/_test_util.gd`。

```gdscript
extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	# Arrange
	var scene := load("res://vr_offices/VrOffices.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing scene")
		return
	var world := (scene as PackedScene).instantiate()
	get_root().add_child(world)
	await process_frame

	# Act
	# ... 调用你的行为 ...

	# Assert
	if not T.require_true(self, true, "Expected ..."):
		return

	# Cleanup（建议做，避免下一测污染）
	var bgm := world.get_node_or_null("Bgm") as AudioStreamPlayer
	if bgm != null:
		bgm.stop()
		bgm.stream = null
	get_root().remove_child(world)
	world.free()
	await process_frame

	T.pass_and_quit(self)
```

`tests/_test_util.gd` 里最常用：
- `T.require_true(...)`
- `T.require_eq(...)`
- `T.fail_and_quit(...)`
- `T.pass_and_quit(...)`

---

## 4) 我在这项目里踩过的坑（高频）

### 坑 A：UI 状态刚改就断言，偶发失败

**现象**：本地偶尔红、CI 绿，或者相反。  
**解法**：关键动作后补 `await process_frame`，让 UI/信号稳定一帧再断言。

### 坑 B：测试之间互相污染（存档、会话）

**现象**：单跑绿，整套红。  
**解法**：每个测试用唯一 `save_id`，推荐：

```gdscript
var save_id := "slot_test_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
```

### 坑 C：异步服务在测试里“偷偷运行”导致干扰

**现象**：你测 UI 返回流程，但后台 summary/网络任务打断。  
**解法**：在需要纯 UI 验证时，临时把服务移出组（按当前仓库习惯）：

```gdscript
var skills_service := world.get_node_or_null("NpcSkillsService") as Node
if skills_service != null:
	skills_service.remove_from_group("vr_offices_npc_skills_service")
```

### 坑 D：Godot 警告升级为错误（尤其 strict 模式）

**现象**：脚本 reload 报 `SHADOWED_VARIABLE_BASE_CLASS`。  
**解法**：不要用会遮蔽基类成员的变量名（比如 `Control` 里的 `size`）。

---

## 5) 推荐开发节奏（真省时间）

1. 先写一个失败测试（Red）
2. 跑单测确认“真的红”
3. 只写最小实现让它变绿（Green）
4. 跑相关回归（同目录 2~5 个）
5. 最后再跑 suite（如 `-Suite vr_offices`）

不要一上来跑全量；先单测闭环，速度快很多。

---

## 6) 一个可复制的“回归清单”

当你改的是 `vr_offices` 对话/UI 相关，建议至少跑：

```powershell
scripts\run_godot_tests.ps1 -One tests\projects\vr_offices\test_vr_offices_smoke.gd
scripts\run_godot_tests.ps1 -One tests\projects\vr_offices\test_vr_offices_npc_skills_overlay.gd
scripts\run_godot_tests.ps1 -One tests\projects\vr_offices\test_vr_offices_npc_dialogue_shell_layout.gd
scripts\run_godot_tests.ps1 -Suite vr_offices
```

---

## 7) 出问题时如何最快定位

- 先单跑出错文件：`-One <test_xxx.gd>`
- 加 `-ExtraArgs --verbose`
- 看失败点是否是：
  - 断言写错（期望错）
  - 时序问题（少 `await process_frame`）
  - 数据污染（save_id/缓存没隔离）
  - 后台服务干扰（组/信号）

如果你愿意，我可以再给你补一份“**最常见 10 类 Godot 测试失败 -> 对应排查命令**”速查表。
